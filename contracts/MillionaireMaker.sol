// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";

interface USDCToken {
    function balanceOf(address account) external view returns (uint256);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function allowance(address owner, address spender)
        external
        returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function approve(address spender, uint256 value) external returns (bool);
}

// Mainner USDC contract: 0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48

// TODO this can be done to be reusable(multiple drawings/seassons)
contract MillionaireMaker is Ownable {
    // Note we instatiate to 1 instead of 0, which will use 15k gas less
    uint256 ticketCount = 1;
    // Note we use one index higher which avoids using `<=` as solidity counts this as 2 opcodes instead of 1 for `<`
    uint256 maxIndex = 1_000_001;

    mapping(uint256 => address) tickets;

    USDCToken public usdcToken;

    constructor() {
        // Note this is mainnet address
        usdcToken = USDCToken(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    }

    function setUsdcTokenAddress(address _usdcToken) external onlyOwner {
        usdcToken = USDCToken(_usdcToken);
    }

    // For obtaining signatures look into https://yos.io/2018/11/16/ethereum-signatures/#verification
    function approve(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        usdcToken.permit(msg.sender, address(this), amount, deadline, v, r, s);
    }

    // Note this allows buying multiple tickets
    function buyTickets(uint256 count) external {
        address _owner = msg.sender;
        uint256 _ticketCount = ticketCount;
        require(
            _ticketCount + count < maxIndex,
            "Not enough tickets left for sale"
        );
        uint256 amount = count * 1_000_000;
        usdcToken.transferFrom(msg.sender, address(this), amount);
        for (uint256 i; i < count; i++) {
            tickets[_ticketCount + i] = _owner;
        }
        _ticketCount += count;
    }

    // Note this can easily be called in the buyTicket and auto draw at 1_000_000 buys
    function drawWinner() external onlyOwner {
        uint256 winnerTicket = randomTicket();
        address winnerAddress = tickets[winnerTicket];
        uint256 winnings = ticketCount * 1_000_000;
        usdcToken.approve(winnerAddress, winnings);
        usdcToken.transferFrom(address(this), winnerAddress, winnings);
    }

    function randomTicket() internal view returns (uint256) {
        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    block.coinbase,
                    block.difficulty,
                    block.gaslimit,
                    block.timestamp
                )
            )
        ) % ticketCount;

        return random;
    }
}
