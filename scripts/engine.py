from enforce_typing import enforce_types

@enforce_types
def run(runresult_csv:str):
        

    s = [] #for console logging
    dataheader = [] # for csv logging: list of string
    datarow = [] #for csv logging: list of float

    #SimEngine already logs: Tick, Second, Min, Hour, Day, Month, Year
    #So we log other things...

    s += ["; granter OCEAN=%s, USD=%s" % (g.OCEAN(), g.USD())]
    dataheader += ["granter_OCEAN", "granter_USD"]
    datarow += [g.OCEAN(), g.USD()]

    #done
    return s, dataheader, datarow
