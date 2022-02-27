from enforce_typing import enforce_types

@enforce_types
def run(runresult_csv:str):
        

    s = [] #for console logging
    dataheader = [] # for csv logging: list of string
    datarow = [] #for csv logging: list of float

    #SimEngine already logs: Tick, Second, Min, Hour, Day, Month, Year
    #So we log other things...
    g_OCEAN, g_USD = 10.0, 20.0 

    s += ["; granter OCEAN=%s, USD=%s" % (g_OCEAN, g_USD)]
    dataheader += ["granter_OCEAN", "granter_USD"]
    datarow += [g_OCEAN, g_USD]

    #done
    return s, dataheader, datarow
