#!/usr/bin/env python

import os
import sys

import brownie

BROWNIE_PROJECT = brownie.project.load("./", name="MyProject")

NETWORKS = ['development', 'eth_mainnet'] #development = ganache

# ========================================================================
HELP_MAIN = """
Vesting wallet main help

Usage: vw help|token|fund|wait|release

  vw help - this message
  vw token - create token, for testing
  vw fund - send funds with vesting wallet
  vw mine - force chain to pass time (ganache only)
  vw release - request vesting wallet to release funds

Typical usage flows:
  Run on ganache: token -> fund -> mine -> release
  Run on testnet w test token: token -> fund -> (wait) -> release
  Run on testnet w existing token: fund -> (wait) -> release
  Run on mainnet w test token: token -> fund -> (wait) -> release
  Run on mainnet w existing token: fund -> (wait) -> release
"""
def do_help():
    print(HELP_MAIN)
    sys.exit(0)


# ========================================================================
def do_token():
    HELP_TOKEN = f"""
    Vesting wallet create test token

    Usage: vw token NETWORK

     NETWORK -- one of {NETWORKS}
    """
    if len(sys.argv) not in [3]:
        print(HELP_TOKEN)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "token"
    NETWORK = sys.argv[2]

    print(f"Arguments: NETWORK={NETWORK}")

    #error handling
    if NETWORK not in NETWORKS:
        print(f"Unknown network '{NETWORK}', exiting.")
        sys.exit(0)

    #brownie setup
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = accounts[0] #FIXME for non-ganache

    #deploy wallet
    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TST", "Test Token", 18, 1e21, {"from": from_account}
    )
    print("Token deployed:")
    print(f"  symbol: {token.symbol()}")
    print(f"  name: {token.name()}")
    print(f"  address: {token.address}")
    print(f"  totalSupply: {token.totalSupply()}")
    print(f"  deployer balance: {token.balanceOf(from_account)}")
    print("Done.")
    
# ========================================================================
def do_fund():
    HELP_FUND = f"""
    Vesting wallet - send funds with vesting wallet

    Usage: vw fund AMT TOKEN_ADDR LOCK_TIME TO_ADDR NETWORK

     AMT -- e.g. '1000' (base-18, not wei)
     TOKEN_ADDR -- address of token being sent. Eg 0x967da4048cd07ab37855c090aaf366e4ce1b9f48 for OCEAN on eth mainnet
     LOCK_TIME -- Eg '10' (10 seconds) or '63113852' (2 years)
     TO_ADDR -- address of beneficiary
     NETWORK -- one of {NETWORKS}
    """

    if len(sys.argv) not in [7]:
        print(HELP_FUND)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "fund"
    AMT = float(sys.argv[2])
    TOKEN_ADDR = sys.argv[3]
    LOCK_TIME = int(sys.argv[4])
    TO_ADDR = sys.argv[5]
    NETWORK = sys.argv[6]
    print(
        f"Arguments: AMT={AMT}, TOKEN_ADDR={TOKEN_ADDR}, "
        f", LOCK_TIME={LOCK_TIME}, TO_ADDR={TO_ADDR}, NETWORK={NETWORK}"
    )

    #error handling
    if NETWORK not in NETWORKS:
        print(f"Unknown network '{NETWORK}', exiting.")
        sys.exit(0)

    #brownie setup
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = accounts[0] #FIXME for non-ganache

    #grab token
    token = BROWNIE_PROJECT.SimpleToken.at(TOKEN_ADDR)
    print(f"Token symbol: {token.symbol()}")

    #deploy vesting wallet
    print("Deploy vesting wallet...")
    start_timestamp = chain[-1].timestamp + 5  # magic number
    vesting_wallet = BROWNIE_PROJECT.VestingWallet.deploy(
        BENEFICIARY, start_timestamp, LOCK_TIME, {"from": from_account}
    )

    #send tokens to vesting wallet
    print("Fund vesting wallet...")
    token.transfer(vesting_wallet, toBase18(AMT), {"from": from_account})

    print("Done.")


# ========================================================================
def do_mine():
    HELP_MINE = f"""
    Vesting wallet - force chain to pass time (ganache only)

    Usage: vw mine BLOCKS TIMEDELTA

     BLOCKS -- e.g. 3
     TIMEDELTA -- e.g. 100
    """
    if len(sys.argv) not in [4]:
        print(HELP_MINE)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "mine"
    BLOCKS = sys.argv[2]
    TIMEDELTA = sys.argv[3]

    print(f"Arguments: BLOCKS={BLOCKS}, TIMEDELTA={TIMEDELTA}")

    #brownie setup
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = accounts[0] #FIXME for non-ganache

    #make time pass
    chain.mine(blocks=BLOCKS, timedelta=TIMEDELTA)
    
    print("Done.")

# ========================================================================
def do_release():
    HELP_RELEASE = f"""
    Vesting wallet - request vesting wallet to release funds

    Usage: vw release WALLET_ADDR TOKEN_ADDR

     TOKEN_ADDR -- e.g. '0x123..'
    """
    if len(sys.argv) not in [4]:
        print(HELP_RELEASE)
        sys.exit(0)

    # extract inputs
    assert sys.argv[1] == "release"
    WALLET_ADDR = sys.argv[2]
    TOKEN_ADDR = sys.argv[3]

    print(f"Arguments: WALLET_ADDR={WALLET_ADDR}, TOKEN_ADDR={TOKEN_ADDR}")

    #brownie setup
    brownie.network.connect(NETWORK) 
    accounts = brownie.network.accounts
    chain = brownie.network.chain
    from_account = accounts[0] #FIXME for non-ganache

    #release the token
    vesting_wallet = BROWNIE_PROJECT.VestingWallet.at(WALLET_ADDR)
    vesting_wallet.release(TOKEN_ADDR, {"from": from_account})
    
    print("Done.")

    
# ========================================================================
# main
def do_main():
    if len(sys.argv) == 1 or sys.argv[1] == "help":
        do_help()

    elif sys.argv[1] == "token":
        do_token()
    elif sys.argv[1] == "fund":
        do_fund()
    elif sys.argv[1] == "mine":
        do_mine()
    elif sys.argv[1] == "release":
        do_release()
    else:
        do_help()

if __name__ == "__main__":
    do_main()