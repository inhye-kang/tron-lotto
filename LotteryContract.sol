pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LotteryContract is ReentrancyGuard, Ownable {
    IERC20 public token;
    uint256 public ticketPrice;
    uint256 public jackpot;
    uint256 public drawInterval;
    uint256 public lastDrawTime;
    address[] public participants;
    mapping(address => uint256) public ticketCount;
    address public lastWinner;

    event TicketPurchased(address indexed buyer, uint256 amount);
    event WinnerSelected(address indexed winner, uint256 amount);
    event TicketPriceChanged(uint256 newPrice);
    event DrawIntervalChanged(uint256 newInterval);

    constructor(address _tokenAddress, uint256 _ticketPrice, uint256 _drawInterval) {
        token = IERC20(_tokenAddress);
        ticketPrice = _ticketPrice;
        drawInterval = _drawInterval;
        lastDrawTime = block.timestamp;
    }

    function buyTickets(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Must buy at least one ticket");
        uint256 totalCost = ticketPrice * _amount;
        require(token.allowance(msg.sender, address(this)) >= totalCost, "Insufficient token allowance");
        require(token.transferFrom(msg.sender, address(this), totalCost), "Token transfer failed");

        ticketCount[msg.sender] += _amount;
        for (uint256 i = 0; i < _amount; i++) {
            participants.push(msg.sender);
        }
        jackpot += totalCost;

        emit TicketPurchased(msg.sender, _amount);
    }

    function drawWinner() external nonReentrant {
        require(block.timestamp >= lastDrawTime + drawInterval, "It's not time for the draw yet");
        require(participants.length > 0, "No participants in the lottery");

        uint256 winnerIndex = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, participants.length))) % participants.length;
        address winner = participants[winnerIndex];

        uint256 prize = jackpot;
        jackpot = 0;
        lastWinner = winner;

        require(token.transfer(winner, prize), "Failed to transfer prize to winner");

        emit WinnerSelected(winner, prize);

        // Reset for next round
        delete participants;
        lastDrawTime = block.timestamp;
    }

    function getTicketCount(address _participant) external view returns (uint256) {
        return ticketCount[_participant];
    }

    function getParticipantCount() external view returns (uint256) {
        return participants.length;
    }

    function setTicketPrice(uint256 _newPrice) external onlyOwner {
        ticketPrice = _newPrice;
        emit TicketPriceChanged(_newPrice);
    }

    function setDrawInterval(uint256 _newInterval) external onlyOwner {
        drawInterval = _newInterval;
        emit DrawIntervalChanged(_newInterval);
    }

    function withdrawTokens(uint256 _amount) external onlyOwner {
        require(token.transfer(owner(), _amount), "Token transfer failed");
    }
}