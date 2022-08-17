// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

error Unauthorized();
error LowAmount();
error NotWhitelisted();
error InsufficientBalance();
error WrongId();
error LongName();
error ZeroAddress();

contract GasContract {
    bool private constant tradeFlag = true;
    bool private constant dividendFlag = true;
    uint256 private constant tradePercent = 12;
    address private immutable contractOwner;
    uint256 public immutable totalSupply; // cannot be updated

    uint96 private paymentCounter;
    address[5] public administrators;

    mapping(address => uint256) public whitelist;
    mapping(address => uint256) private balances;
    mapping(address => Payment[]) private payments;
    mapping(address => bool) private isAdmin;

    History[] private paymentHistory; // when a payment was updated
    mapping(address => ImportantStruct) public whiteListStruct;

    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    struct ImportantStruct {
        uint128 valueA; // max 3 digits
        uint128 valueB; // max 3 digits
        uint256 bigValue;
    }

    struct Payment {
        address admin; // administrators address
        bytes8 recipientName; // max 8 characters
        PaymentType paymentType;
        bool adminUpdated;
        uint256 amount;
        address recipient;
        uint96 paymentID;
    }

    struct History {
        uint32 lastUpdate;
        uint32 blockNumber;
        address updatedBy;
    }

    event AddedToWhitelist(address userAddress, uint256 tier);
    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        string recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;
        for (uint256 i = 0; i < administrators.length; ) {
            if (_admins[i] != address(0)) {
                administrators[i] = _admins[i];
                if (_admins[i] == msg.sender) {
                    balances[msg.sender] = _totalSupply;
                    emit supplyChanged(msg.sender, _totalSupply);
                } else {
                    emit supplyChanged(_admins[i], 0); // correct?
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function getPaymentHistory()
        public
        view
        returns (History[] memory paymentHistory_)
    {
        return paymentHistory;
    }

    function balanceOf(address _user) public view returns (uint256 balance_) {
        return balances[_user];
    }

    function getTradingMode() public pure returns (bool mode_) {
        return tradeFlag || dividendFlag;
    }

    function addHistory(address _updateAddress) private {
        History memory history;
        history.blockNumber = uint32(block.number);
        history.lastUpdate = uint32(block.timestamp);
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
    }

    function getPayments(address _user)
        public
        view
        returns (Payment[] memory payments_)
    {
        if (_user == address(0)) revert ZeroAddress();
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) public returns (bool status_) {
        if (balances[msg.sender] < _amount) revert InsufficientBalance();
        if (bytes(_name).length > 8) revert LongName();
        unchecked {
            balances[msg.sender] -= _amount;
            balances[_recipient] += _amount;
            emit Transfer(_recipient, _amount);
            Payment memory payment;
            payment.paymentType = PaymentType.BasicPayment;
            payment.recipient = _recipient;
            payment.amount = _amount;
            payment.recipientName = bytes8(bytes(_name));
            payment.paymentID = ++paymentCounter;
            payments[msg.sender].push(payment); // @audit gas update to mapping?
            return tradePercent > 0;
        }
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public {
        if (!isAdmin[msg.sender] && contractOwner != msg.sender)
            revert Unauthorized();
        if (_ID == 0) revert WrongId();
        if (_amount == 0) revert LowAmount();
        Payment[] storage paymentsOfUser = payments[_user];
        uint256 length = paymentsOfUser.length;
        for (uint256 i = 0; i < length; ) {
            if (paymentsOfUser[i].paymentID == _ID) {
                paymentsOfUser[i].adminUpdated = true;
                paymentsOfUser[i].admin = _user;
                paymentsOfUser[i].paymentType = _type;
                paymentsOfUser[i].amount = _amount;
                addHistory(_user);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    string(abi.encodePacked(paymentsOfUser[i].recipientName))
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint8 _tier) public {
        if (!isAdmin[msg.sender] && contractOwner != msg.sender)
            revert Unauthorized();
        if (_tier > 3) {
            whitelist[_userAddrs] = 3;
        } else if (_tier > 0) {
            whitelist[_userAddrs] = _tier;
        }
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct memory _struct
    ) public {
        if (whitelist[msg.sender] == 0) revert NotWhitelisted();
        if (balances[msg.sender] < _amount) revert InsufficientBalance();
        if (_amount < 4) revert LowAmount();
        unchecked {
            balances[msg.sender] -= _amount;
            balances[_recipient] += _amount;
            uint256 whitelistTier = whitelist[msg.sender];
            balances[msg.sender] += whitelistTier;
            balances[_recipient] -= whitelistTier;
        }

        whiteListStruct[msg.sender].valueA = _struct.valueA;
        whiteListStruct[msg.sender].bigValue = _struct.bigValue;
        whiteListStruct[msg.sender].valueB = _struct.valueB;
        emit WhiteListTransfer(_recipient);
    }
}
