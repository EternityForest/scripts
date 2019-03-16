import os,re,time,subprocess,hashlib,struct,threading,atexit,select,traceback

alsa_in_instances={}
alsa_out_instances ={}

failcards = {}

#The options we use to tune alsa_in and alsa_out
#so they don't sound horrid
iooptions=["-p", "128","-m:", "64", "-q","1"]

toretry_in = {}
toretry_out ={}

def compressnumbers(s):
    """Take a string that's got a lot of numbers and try to make something 
        that represents that number. Tries to make
        unique strings from things like usb-0000:00:14.0-2
    
    """
    n = ''
    currentnum = ''
    for i in s:
        if i in '0123456789':
            #Exclude leading zeros
            if currentnum or (not(i=='0')):
                currentnum+=i
        else:
            n+=currentnum
            currentnum=''

    return n+currentnum

def startJack():
    #Start the JACK server.
    global jackp

    #Get rid of old stuff 
    try:
        subprocess.check_call(['killall','jackd'])
    except:
        pass
    try:
        subprocess.check_call(['killall','alsa_in'])
    except:
        pass
    try:
        subprocess.check_call(['killall','alsa_out'])
    except:
        pass
    jackp =subprocess.Popen("jackd --realtime -d dummy -p 64",shell=True,stdin=subprocess.DEVNULL,stderr=subprocess.DEVNULL,stdout=subprocess.DEVNULL)    


def cleanup():
    with lock:
        try:
            jackp.kill()
        except:
            pass
        for i in alsa_in_instances:
            alsa_in_instances[i].terminate()
        for i in alsa_out_instances:
            alsa_out_instances[i].terminate()

atexit.register(cleanup)
lock=threading.Lock()


def closeAlsaProcess(i, x):
    #Why not a proper terminate?
    #It seemed to ignore that sometimes.
    x.kill()
    x.wait()

def daemon():
    oldi,oldo  = None,None
    while 1:
        time.sleep(3)

        #There seems to be a bug in reading errors from the process
        #Right now it's a TODO, but most of the time
        #we catch things in the add/remove detection anyway
        with lock:
            try:
                tr =[]
                for i in alsa_out_instances:
                  
                    x=readAllSoFar(alsa_out_instances[i])
                    e=readAllErrSoFar(alsa_out_instances[i])

                    if b"err =" in x+e or alsa_out_instances[i].poll():
                        print("Error in "+ i +(x+e).decode("utf8"))
                        closeAlsaProcess(i, alsa_out_instances[i])
                        tr.append(i)
                        #We have to delete the busy stuff but we can
                        #retry later
                        if b"busy" in (x+e):
                            toretry_out[i]=True
                        print("Removed "+i+"o")

                    elif not alsa_out_instances[i].poll()==None:
                        tr.append(i)
                        print("Removed "+i+"o")

                for i in tr:
                    del alsa_out_instances[i]

                tr =[]
                for i in alsa_in_instances:
                   
                    x= readAllSoFar(alsa_in_instances[i])
                    e=readAllErrSoFar(alsa_in_instances[i])

                    if b"err =" in x+e or alsa_in_instances[i].poll():
                        print("Error in "+ i +(x+e).decode("utf8"))
                        closeAlsaProcess(i, alsa_in_instances[i])   
                        tr.append(i)
                        if b"busy" in (x+e):
                            toretry_in[i]=True
                        print("Removed "+i+"i")

                    elif not alsa_in_instances[i].poll()==None:
                        tr.append(i)
                        print("Removed "+i+"i")

                for i in tr:
                    del alsa_in_instances[i]
            except:
                print(traceback.format_exc())



            ##HANDLE CREATING AND GC-ING things
            inp,op = listSoundCardsByPersistentName()
            #This is how we avoid constantky retrying to connect the same few
            #clients that fail, which might make a bad periodic click that nobody
            #wants to hear.
            if (inp,op)==(oldi,oldo):

                #However some things we need to retry.
                #Device or resource busy being the main one
                for i in inp:
                    if i in toretry_in:
                        del toretry_in[i]
                        if not i in alsa_in_instances:
                            x = subprocess.Popen(["alsa_in"]+iooptions+["-d", inp[i][0], "-j",i+"i"],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                            alsa_in_instances[i]=x
                            print("Added "+i+"i")
        
                for i in op:
                    if i in toretry_out:
                        del toretry_out[i]
                        if not i in alsa_out_instances:
                            x = subprocess.Popen(["alsa_out"]+iooptions+["-d", op[i][0], "-j",i+"o"]+iooptions,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                            alsa_out_instances[i]=x
                            print("Added "+i+"o")
                continue
            oldi,oldo =inp,op

            for i in inp:
                if not i in alsa_in_instances:
                    x = subprocess.Popen(["alsa_in"]+iooptions+["-d", inp[i][0], "-j",i+"i"],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                    alsa_in_instances[i]=x
                    print("Added "+i+"i")
        
            for i in op:
                if not i in alsa_out_instances:
                    x = subprocess.Popen(["alsa_out"]+iooptions+["-d", op[i][0], "-j",i+"o"]+iooptions,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
                    alsa_out_instances[i]=x
                    print("Added "+i+"o")


            #In case alsa_in doesn't properly tell us about a removed soundcard
            #Check for things that no longer exist.
            try:
                tr =[]
                for i in alsa_out_instances:
                    if not i in op:
                        tr.append(i)
                for i in tr:
                    print("Removed "+i+"o because the card was removed")
                    del alsa_out_instances[i]

                tr =[]
                for i in alsa_in_instances:
                    if not i in inp:
                        tr.append(i)
                for i in tr:
                    print("Removed "+i+"i because the card was removed")
                    del alsa_in_instances[i]
            except:
                print(traceback.format_exc())


            
def cleanupstring(s):
    "Get rid of special characters and common redundant words that provide no info"
    x = s.replace(" ","").replace("\n","").replace("*","").replace("(","")
    x=x.replace(")","").replace("-","").replace(":",".").replace("Audio","")
    x=x.replace("Lpe","").replace("-","")
    return x

def cardsfromregex(m, cards,usednames = []):
    """Given the regex matches from arecord or aplay, match them up to the actual 
    devices and give them memorable aliases"""

    d = {}

    #Why sort? We need consistent ordering so that our conflict resolution
    #has the absolute most possible consistency
    m= sorted(m)
    for i in m:
        #We generate a name that contains both the device path and subdevice
        generatedName = cards[i[0]]+"."+i[2]

        numberstring = compressnumbers(cards[i[0]])

        h = memorableHash(cards[i[0]]+":"+i[2])
        n = cleanupstring(i[3])
        jackname =n+'_'+h
        jackname+=numberstring
        jackname=jackname[:28]

        #If there's a collision, we're going to redo everything
        #This of course will mean we're going back to 
        while (jackname in d) or jackname in usednames:
            h = memorableHash(jackname+cards[i[0]]+":"+i[2])
            n = cleanupstring(i[3])
            jackname =n+'_'+h
            jackname+=numberstring
            jackname=jackname[:28]


    
        try:
            d[jackname]  = ("hw:"+i[0]+","+i[2], cards[i[0]], (int(i[0]), int(i[2])))
        except KeyError:
            d[jackname] = ("hw:"+i[0]+","+i[2], cards[i[0]], int(i[0]), int(i[2]))
    return d


def readAllSoFar(proc, retVal=b''): 
  counter = 128
  while counter:
    x =(select.select([proc.stdout],[],[],0.1)[0])
    if x:   
        retVal+=proc.stdout.read(1)
    else:
        break
    counter -=1
  return retVal

def readAllErrSoFar(proc, retVal=b''): 
  counter = 128
  while counter:
    x =(select.select([proc.stderr],[],[],0.1)[0])
    if x:   
        retVal+=proc.stderr.read(1)
    else:
        break
    counter -=1
  return retVal

def listSoundCardsByPersistentName():
    """
        Only works on linux or maybe mac

       List devices in a dict indexed by human-readable and persistant easy to memorize
       Identifiers. Output is tuples:
       (cardnamewithsubdev(Typical ASLA identifier),physicalDevice(persistent),devicenumber, subdevice)
    
    """
    with open("/proc/asound/cards") as f:
        d = f.read()

    #RE pattern produces cardnumber, cardname, locator
    c = re.findall(r"[\n\r]*\s*(\d)+\s*\[(\w+)\s*\]:\s*.*?[\n\r]+\s*.*? at (.*?)[\n\r]+",d)

    #Catch the ones that don't have an "at"
    c2 = re.findall(r"[\n\r]*\s*(\d)+\s*\[(\w+)\s*\]:\s*.*?[\n\r]+\s*(.*?)[\n\r]+",d)

    cards = {}
    #find physical cards
    for i in c:
        n = i[2].strip().replace(" ","").replace(",fullspeed","").replace("[","").replace("]","")
        cards[i[0]] = n

    #find physical cards
    for i in c2:
        #Ones with at are caught in c
        if ' at ' in i[2]:
            continue
        n = i[2].strip().replace(" ","").replace(",fullspeed","").replace("[","").replace("]","")
        cards[i[0]] = n


    x = subprocess.check_output(['aplay','-l'],stderr=subprocess.DEVNULL).decode("utf8")
    #Groups are cardnumber, cardname, subdevice, longname
    sd = re.findall(r"card (\d+): (\w*)\s\[.*?\], device (\d*): (.*?)\s+\[.*?]",x)

    outputs= cardsfromregex(sd,cards)
   

    x = subprocess.check_output(['arecord','-l'],stderr=subprocess.DEVNULL).decode("utf8")
    #Groups are cardnumber, cardname, subdevice, longname
    sd = re.findall(r"card (\d+): (\w*)\s\[.*?\], device (\d*): (.*?)\s+\[.*?]",x)
    inputs=cardsfromregex(sd,cards)

    return inputs,outputs



eff_wordlist = [s.split()[1] for s in open(os.path.join(os.path.dirname(__file__),'words_eff.txt'))]

def memorableHash(x, num=3, separator=""):
    "Use the diceware list to encode a hash. Not meant to be secure."
    o = ""

    if isinstance(x, str):
        x = x.encode("utf8")
    for i in range(num):
        while 1:
            x = hashlib.sha256(x).digest()
            n = struct.unpack("<Q",x[:8])[0]%len(eff_wordlist)
            e = eff_wordlist[n]
            #Don't have a word that starts with the letter the last one ends with
            #So it's easier to read
            if o:
                if e[0] == o[-1]:
                    continue
                o+=separator+e
            else:
                o=e
            break
    return o


inp,op = listSoundCardsByPersistentName()
startJack()
daemon()
