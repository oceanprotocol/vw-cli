import brownie

from util.constants import BROWNIE_PROJECT

accounts = brownie.network.accounts
alice = accounts[0]
bob = accounts[1]
carol = accounts[2]
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

def test_shares():
    token = _deployToken()
    shares = [100, 200, 300]

    router = _deployRouter(shares, [alice, bob, carol])
    token.transfer(router, 600, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 200
    assert router.shares(carol) == 300

    assert router.totalShares() == 600

    # remove bob
    router.removePayee(bob, {"from": alice})
    assert router.shares(alice) == 100
    assert router.shares(bob) == 0
    assert router.shares(carol) == 300

    assert router.totalShares() == 400

    # adjuts carol's shares

    router.adjustShare(carol, 100, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 0
    assert router.shares(carol) == 100

    assert router.totalShares() == 200

    router.addPayee(bob, 100, {"from": alice})
    router.adjustShare(bob, 200, {"from": alice})
    alice_before = token.balanceOf(alice)
    router.release(token.address, {"from": carol})
    alice_after = token.balanceOf(alice)

    assert alice_after - alice_before == 150
    assert token.balanceOf(bob) == 300
    assert token.balanceOf(carol) == 150

    assert router.totalReleased(token) == 600
    assert router.released(token, alice) == 150
    assert router.released(token, bob) == 300
    assert router.released(token, carol) == 150

    router.removePayee(alice, {"from": alice})
    router.removePayee(carol, {"from": alice})
    router.removePayee(bob, {"from": alice})

    router.addPayee(accounts[3], 1000, {"from": alice})
    assert router.shares(accounts[3]) == 1000
    assert router.totalShares() == 1000

    router.release(token.address, {"from": carol})
    assert token.balanceOf(accounts[3]) == 0


def test_add_zero_shares():
    router = _deployRouter([100], [alice])
    with brownie.reverts("Router: shares are 0"):
        router.addPayee(bob, 0, {"from": alice})


def test_remove_nonexistent_payee():
    router = _deployRouter([100], [alice])
    with brownie.reverts("Router: account has no shares"):
        router.removePayee(bob, {"from": alice})


def test_adjust_to_zero():
    router = _deployRouter([100, 200], [alice, bob])
    with brownie.reverts("Router: shares are 0"):
        router.adjustShare(bob, 0, {"from": alice})


def test_add_payee():
    token = _deployToken()
    shares = [100, 200]

    router = _deployRouter(shares, [alice, bob])
    token.transfer(router, 600, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 200

    assert router.totalShares() == 300

    router.addPayee(carol, 100, {"from": alice})
    assert router.shares(alice) == 100
    assert router.shares(bob) == 200
    assert router.shares(carol) == 100

    assert router.totalShares() == 400


def test_adjust_nonexistent_payee_shares():
    router = _deployRouter([100], [alice])

    with brownie.reverts("Router: account has no shares"):
        router.adjustShare(bob, 100, {"from": alice})


def test_adjust_payee_shares():
    router = _deployRouter([100, 200, 300], [alice, bob, carol])

    router.adjustShare(bob, 100, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 100
    assert router.shares(carol) == 300

    assert router.totalShares() == 500


def test_remove_payee():
    router = _deployRouter([100, 200], [alice, bob])

    router.removePayee(bob, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 0

    assert router.totalShares() == 100


def test_admin_functions_only_by_admin():
    router = _deployRouter([100], [alice])

    with brownie.reverts("Ownable: caller is not the owner"):
        router.addPayee(bob, 50, {"from": bob})

    with brownie.reverts("Ownable: caller is not the owner"):
        router.removePayee(bob, {"from": bob})

    with brownie.reverts("Ownable: caller is not the owner"):
        router.adjustShare(bob, 50, {"from": bob})


def test_add_zero_address():
    router = _deployRouter([100], [alice])
    with brownie.reverts("Router: zero address"):
        router.addPayee(
            ZERO_ADDRESS, 50, {"from": alice}
        )


def test_remove_zero_address():
    router = _deployRouter([100], [alice])
    with brownie.reverts("Router: zero address"):
        router.removePayee(
            ZERO_ADDRESS, {"from": alice}
        )


def test_adjust_zero_address_shares():
    router = _deployRouter([100], [alice])
    with brownie.reverts("Router: zero address"):
        router.adjustShare(
            ZERO_ADDRESS, 50, {"from": alice}
        )


def test_readd_payee():
    router = _deployRouter([100, 200], [alice, bob])

    router.removePayee(bob, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 0

    assert router.totalShares() == 100

    router.addPayee(bob, 200, {"from": alice})

    assert router.shares(alice) == 100
    assert router.shares(bob) == 200

    assert router.totalShares() == 300

    with brownie.reverts("Router: account already has shares"):
        router.addPayee(bob, 200, {"from": alice})



def test_send_eth_to_contract():
    router = _deployRouter([100], [alice])
    with brownie.reverts():
        alice.transfer(router, 100)


def _deployRouter(shares, addresses):
    return BROWNIE_PROJECT.Router.deploy(addresses, shares, {"from": accounts[0]})


def _deployToken():
    return BROWNIE_PROJECT.Simpletoken.deploy(
        "TST", "Test Token", 18, 1e21, {"from": accounts[0]}
    )
