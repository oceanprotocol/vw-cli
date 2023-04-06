import brownie
from pytest import approx

from util.base18 import toBase18
from util.constants import BROWNIE_PROJECT

accounts = brownie.network.accounts
account0 = accounts[0]
address1 = brownie.network.accounts[1].address
address2 = brownie.network.accounts[2].address
chain = brownie.network.chain


def test_ownership_and_admin_commands():
    beneficiary = address1
    start_ts = chain.time()
    ts_duration = 1000

    vw1 = BROWNIE_PROJECT.VestingWalletLinear.deploy(
        beneficiary,
        start_ts,
        ts_duration,
        {"from": account0},
    )

    vw2 = BROWNIE_PROJECT.VestingWalletLinear.deploy(
        beneficiary,
        start_ts,
        ts_duration,
        {"from": account0},
    )
    
    for vw in [vw1, vw2]:
        token = BROWNIE_PROJECT.Simpletoken.deploy(
            "TOK", "Test Token", 18, toBase18(100.0), {"from": account0}
        )
        token.transfer(vw.address, toBase18(100.0), {"from": account0})

        assert vw.owner() == account0.address
        
        with brownie.reverts("Ownable: caller is not the owner"):
            vw.changeBeneficiary(address2, {"from": account1})

        with brownie.reverts("Ownable: caller is not the owner"):
            vw.rennounceVesting(token.address, {"from": account1})

        assert vw.beneficiary() == address1
        vw.changeBeneficiary(address2, {"from": account0})
        assert vw.beneficiary() == address2

        assert token.balanceOf(vw.address) == toBase18(100.0)
        vw.rennounceVesting(token.address, {"from": account0})
        assert token.balanceOf(vw.address) == toBase18(0.0)
        assert token.balanceOf(account0) == toBase18(100.0)
