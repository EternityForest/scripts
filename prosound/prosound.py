import os,re,time,subprocess,hashlib,struct


alsa_in_instances={}
alsa_out_instances ={}





def daemon():
    while 1:
        time.sleep(3)
        ##HANDLE CREATING AND GC-ING things
        inp,op = listSoundCardsByPersistentName()

        for i in inp:
            if inp[i][2]==(0,0):
                continue
            if not i in alsa_in_instances:
                x = subprocess.Popen(["alsa_in", "-d", inp[i][0], "-j",i])
                alsa_in_instances[i]=x
        for i in op:
            if op[i][2]==(0,0):
                continue
            if not i in alsa_out_instances:
                print(["alsa_in", "-d", op[i][0], "-j",i])
                x = subprocess.Popen(["alsa_in", "-d", op[i][0], "-j",i])
                alsa_out_instances[i]=x

        tr =[]
        for i in alsa_out_instances:
            alsa_out_instances[i].poll()
            tr.append(i)
        for i in tr:
            del alsa_out_instances[i]

        tr =[]
        for i in alsa_in_instances:
            alsa_in_instances[i].poll()
            tr.append(i)
        for i in tr:
            del alsa_out_instances[i]


def listSoundCardsByPersistentName():
    """
        Only works on linux or maybe mac

       List devices in a dict indexed by human-readable and persistant easy to memorize
       Identifiers. Output is tuples:
       (cardnamewithsubdev(Typical ASLA identifier),physicalDevice(persistent),devicenumber, subdevice)

       Indexed by a long name that contains the persistant locator, subdevice,
       prefixed by three words chosen based on a hash, to help you remember.

       An example of a generated name: 'reformerdatebookmaturity-HDMI2-0xef128000irq129:8'
    
       We returm a tuple of 2 dicts, inputs and outputs
    
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


    x = subprocess.check_output(['aplay','-l']).decode("utf8")


    #Groups are cardnumber, cardname, subdevice, longname
    sd = re.findall(r"card (\d+): (\w*)\s\[.*?\], device (\d*): (.*?)\s+\[.*?]",x)

    d = {}
    for i in sd:
        #We generate a name that contains both the device path and subdevice
        generatedName = cards[i[0]]+"."+i[2]

        h = memorableHash(cards[i[0]]+":"+i[2])
        n = i[3].replace(" ","").replace("\n","").replace("*","").replace("(","").replace(")","").replace("-","").replace(":",".")
        z =n+'-'+h
        z=z[:29]
        try:
            d[z]  = ("hw:"+i[0]+","+i[2], cards[i[0]], (int(i[0]), int(i[2])))
        except KeyError:
            d[z] = ("hw:"+i[0]+","+i[2], cards[i[0]], int(i[0]), int(i[2]))


    #Now do the same for the inputs
    inputs={}

    x = subprocess.check_output(['aplay','-l']).decode("utf8")
    #Groups are cardnumber, cardname, subdevice, longname
    sd = re.findall(r"card (\d+): (\w*)\s\[.*?\], device (\d*): (.*?)\s+\[.*?]",x)
    for i in sd:
        #We generate a name that contains both the device path and subdevice
        generatedName = cards[i[0]]+"."+i[2]

        h = memorableHash(cards[i[0]]+":"+i[2])
        n = i[3].replace(" ","").replace("\n","").replace("*","").replace("(","").replace(")","").replace("-","")
        z =n+'-'+h
        z=z[:29]
        try:
            d[z]  = ("hw:"+i[0]+","+i[2], cards[i[0]], (int(i[0]), int(i[2])))
        except KeyError:
            d[z] = ("hw:"+i[0]+","+i[2], cards[i[0]], int(i[0]), int(i[2]))



    return inputs,d



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


daemon()
