import brownie
from pytest import approx

from util.base18 import fromBase18, toBase18
from util.constants import BROWNIE_PROJECT
from matplotlib import pyplot as plt
import numpy as np

accounts = brownie.network.accounts

account0, account1, account2, account3 = (
    accounts[0],
    accounts[1],
    accounts[2],
    accounts[3],
)
address0, address1, address2 = account0.address, account1.address, account2.address
payee1 = address1
payee2 = address2
chain = brownie.network.chain
GOD_ACCOUNT = accounts[9]
TOT_SUPPLY = 503370000 * 1e18
R_SUPPLIES = [
    TOT_SUPPLY * 0.1 - 1000,
    TOT_SUPPLY * 0.15 - 1000,
    TOT_SUPPLY * 0.25 - 1000,
    TOT_SUPPLY * 0.5 - 1000,
]  # FOR EACH RATCHET
sixmonths = 6 * 30 * 24 * 60 * 60


def test_e2e():
    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TOK", "Test Token", 18, toBase18(TOT_SUPPLY), {"from": account0}
    )
    taddress = token.address
    _chain_time = chain.time()
    start_times = [
        _chain_time,
        _chain_time + sixmonths * 2,
        _chain_time + sixmonths * 3,
        _chain_time + sixmonths * 4,
    ]
    vestingwallets = []
    half_life = 4 * 365 * 24 * 60 * 60  # half life is 4 years

    for ratchet_i in range(len(start_times)):
        SUPPLY = R_SUPPLIES[ratchet_i]
        start_ts = start_times[ratchet_i]
        wallet = BROWNIE_PROJECT.VestingWalletHalving.deploy(
            address1,
            start_ts,
            half_life,
            half_life * 5,
            {"from": account0},
        )
        assert token.balanceOf(wallet) == 0
        token.transfer(wallet.address, toBase18(SUPPLY), {"from": account0})
        assert fromBase18(token.balanceOf(wallet)) == approx(SUPPLY)

        vestingwallets.append(wallet)

    # simulate each 7 day for next 9 years
    plts = [[], [], [], []]
    for z in range(9 * 365 // 7):
        chain.sleep(7 * 24 * 60 * 60)
        chain.mine(blocks=1, timedelta=1)
        ts = chain.time()

        contract_amts = [fromBase18(v.releasable(taddress)) for v in vestingwallets]
        approx_amts = [
            _approx(R_SUPPLIES[i], ts - start_times[i], half_life)
            if ts >= start_times[i]
            else 0
            for i in range(len(start_times))
        ]

        for i in range(len(contract_amts)):
            assert contract_amts[i] == approx(
                approx_amts[i], 1e-3
            ), f"{z} {ts} {contract_amts[i]} {approx_amts[i]} {i+1}"
        for i in range(len(contract_amts)):
            plts[i].append(contract_amts[i])

    # save plot
    for i in range(len(plts)):
        # set diff colors
        if i == 0:
            plt.plot(plts[i], color="blue")
        elif i == 1:
            plt.plot(plts[i], color="orange")
        elif i == 2:
            plt.plot(plts[i], color="green")
        elif i == 3:
            plt.plot(plts[i], color="red")
    # plt.savefig("test_e2e.png")

    # take a sum of 4 plots
    sum_vested = [sum(x) for x in zip(*plts)]
    plt.clf()
    plt.plot(sum_vested)
    # plt.savefig("test_e2e_sum.png")

    # save as csv
    # np.savetxt("test_e2e.csv", np.array(plts).T, delimiter=",")
    # save sum as csv
    # np.savetxt("test_e2e_sum.csv", np.array(sum_vested).T, delimiter=",")


def test_e2e_with_release():
    splitter = _deploySplitter([100, 100], [payee1, payee2])
    token = BROWNIE_PROJECT.Simpletoken.deploy(
        "TOK", "Test Token", 18, toBase18(TOT_SUPPLY), {"from": account0}
    )
    taddress = token.address
    _chain_time = chain.time()
    start_times = [
        _chain_time,
        _chain_time + sixmonths * 2,
        _chain_time + sixmonths * 3,
        _chain_time + sixmonths * 4,
    ]  # 6 months apart
    vestingwallets = []
    half_life = 4 * 365 * 24 * 60 * 60  # half life is 4 years

    for ratchet_i in range(len(start_times)):
        SUPPLY = R_SUPPLIES[ratchet_i]
        start_ts = start_times[ratchet_i]
        wallet = BROWNIE_PROJECT.VestingWalletHalving.deploy(
            splitter.address,
            start_ts,
            half_life,
            half_life * 3,
            {"from": account0},
        )
        assert token.balanceOf(wallet) == 0
        token.transfer(wallet.address, toBase18(SUPPLY), {"from": account0})
        assert fromBase18(token.balanceOf(wallet)) == approx(SUPPLY)

        vestingwallets.append(wallet)

    plts = [[], [], [], []]
    # simulate each week for next 9 years
    for z in range(9 * 365 // 7):
        chain.sleep(7 * 24 * 60 * 60)
        chain.mine(blocks=1, timedelta=1)
        ts = chain.time()

        bal_before = fromBase18(token.balanceOf(splitter))

        contract_amts = []
        approx_amts = [
            _approx(R_SUPPLIES[i], ts - start_times[i], half_life)
            - fromBase18(vestingwallets[i].released(taddress))
            if ts >= start_times[i]
            else 0
            for i in range(len(start_times))
        ]
        for v in vestingwallets:
            tx = v.release(taddress, {"from": account1})
            amt = fromBase18(tx.events["ERC20Released"]["amount"])
            contract_amts.append(amt)
            print(R_SUPPLIES[0], ts - start_times[0], half_life, amt)

        bal_after = fromBase18(token.balanceOf(splitter))

        sum_actual = sum(contract_amts)

        assert bal_after - bal_before == approx(sum_actual, 1e-3)

        payee1_before = fromBase18(token.balanceOf(payee1))
        payee2_before = fromBase18(token.balanceOf(payee2))
        splitter.release(taddress, {"from": account0})
        payee1_after = fromBase18(token.balanceOf(payee1))
        payee2_after = fromBase18(token.balanceOf(payee2))

        assert payee1_after - payee1_before == approx(sum_actual / 2, 1e-3)
        assert payee1_after - payee1_before == payee2_after - payee2_before

        for i in range(len(contract_amts)):
            assert contract_amts[i] == approx(
                approx_amts[i], 0.1
            ), f"{z} {ts} {contract_amts[i]} {approx_amts[i]}"
        for i in range(len(contract_amts)):
            plts[i].append(contract_amts[i])

    # save plot
    for i in range(len(plts)):
        # set diff colors
        if i == 0:
            plt.plot(plts[i], color="blue")
        elif i == 1:
            plt.plot(plts[i], color="orange")
        elif i == 2:
            plt.plot(plts[i], color="green")
        elif i == 3:
            plt.plot(plts[i], color="red")

    # make the y axis more detailed
    # plt.savefig("test_e2e_with_release.png")

    plt.clf()
    # take a sum of 4 plots
    sum_vested = [sum(x) for x in zip(*plts)]
    plt.plot(sum_vested)
    #plt.yticks(np.arange(0, max(sum_vested), 100000))
    #plt.xticks(np.arange(0, len(sum_vested), 20))
    # increase width of the plot
    fig = plt.gcf()
    fig.set_size_inches(18.5, 10.5)
    # plt.savefig("test_e2e_with_release_sum.png")

    # save as csv
    # np.savetxt("test_e2e_with_release.csv", np.array(plts).T, delimiter=",")

    # save sum as csv
    # np.savetxt("test_e2e_with_release_sum.csv", np.array(sum_vested).T, delimiter=",")


def _approx(value, t, h):
    t = int(t)
    h = int(h)
    value = int(value)
    p = value >> int(t / h)
    t %= h
    return value - p + (p * t) / h / 2


def _deploySplitter(shares, addresses):
    return BROWNIE_PROJECT.Splitter.deploy(addresses, shares, {"from": accounts[0]})
