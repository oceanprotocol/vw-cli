// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (finance/PaymentSplitter.sol)

pragma solidity ^0.8.0;

import "OpenZeppelin/openzeppelin-contracts@4.7.0/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.0/contracts/utils/Address.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.0/contracts/access/Ownable.sol";

contract Router is Ownable {
    uint256 private _totalShares;
    uint256 private _totalReleased;
    
    event PayeeAdded(address account, uint256 shares);
    event PaymentReleased(IERC20 indexed token, uint256 amount);
    event PayeeRemoved(address account, uint256 shares);
    event PayeeShareAdjusted(address account, uint256 shares, uint256 oldShares);

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;

    constructor(address[] memory payees, uint256[] memory shares_) payable {
        require(payees.length == shares_.length, "Router: payees and shares length mismatch");
        require(payees.length > 0, "Router: no payees");

        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares_[i]);
        }
    }

    // ---------------------------- getters ----------------------------
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    // ---------------------------- external functions ----------------------------
    function release(IERC20 token) external {
        uint256 balance = token.balanceOf(address(this));
        uint256 total = 0;
        for(uint256 i = 0; i < _payees.length; i++) {
            address payee = _payees[i];
            uint256 payment = balance * _shares[payee] / _totalShares;
            if (payment > 0) {
                _released[payee] = _released[payee] + payment;
                _totalReleased = _totalReleased + payment;
                SafeERC20.safeTransfer(token, payee, payment);
                total += payment;
            }
        }
        emit PaymentReleased(token.address, total);
    }

     function addPayee(address account, uint256 shares_) external onlyOwner {
        _addPayee(account, shares_);
    }

    function removePayee(address account) external onlyOwner {
        _removePayee(account);
    }

    function adjustShare(address account, uint256 shares_) external onlyOwner {
        _adjustShare(account, shares_);
    }


    
    // ---------------------------- private functions ----------------------------

    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "Router: account is the zero address");
        require(shares_ > 0, "Router: shares are 0");
        require(_shares[account] == 0, "Router: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeAdded(account, shares_);
    }


    function _removePayee(address account) private {
        require(account != address(0), "Router: account is the zero address");
        require(_shares[account] > 0, "Router: account has no shares");

        for (uint256 i = 0; i < _payees.length; i++) {
            if (_payees[i] == account) {
                _payees[i] = _payees[_payees.length - 1];
                _totalShares = _totalShares - _shares[account];
                _shares[account] = 0;
                _payees.pop();
                break;
            }
        }
        emit PayeeRemoved(account, shares_);
    }

    function _adjustShare(address account, uint256 shares_) private {
        require(account != address(0), "Router: account is the zero address");
        require(shares_ > 0, "Router: shares are 0");
        require(_shares[account] > 0, "Router: account has no shares");

        _totalShares = _totalShares - _shares[account];
        _shares[account] = shares_;
        _totalShares = _totalShares + shares_;
        emit PayeeShareAdjusted(account, shares_, oldShares);
    }
   
    receive() external payable virtual {
        revert("Router: cannot receive ether");
    }
}