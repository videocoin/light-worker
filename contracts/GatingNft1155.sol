// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./LightWorkerDao.sol";
import "./RewardMgr.sol";


/**
 * @dev {ERC1155} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 *
 * _Deprecated in favor of https://wizard.openzeppelin.com/[Contracts Wizard]._
 */
contract GatingNft1155 is Context,  ERC1155Burnable, ERC1155Pausable {
    
    event Deposit(address, uint);

    address daoContract =  address(0);
    mapping (uint => address) listDao;
    mapping (uint => address) listRewardMgr;

    // Token ID enumeration
    uint256[] public tokenIDs;
    mapping (uint256 => bool) public isTokenID;
    address owner;

    /**
     *  Modifiers
     */

    modifier onlyOwner() {
        require(msg.sender == address(owner));
        _;
    }
    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, and `PAUSER_ROLE` to the account that
     * deploys the contract.
     */
    constructor(string memory uri) ERC1155(uri) {
        owner =  _msgSender();
    }

    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC1155-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual {
        //require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");
        if(isTokenID[id]) {
            address operator =  getTokenOperator(id);
            require (msg.sender == operator, "Token ID already owned");
            require (msg.sender == to, "Only self minting allowed");
        }
        _mint(to, id, amount, data);   
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        require(false, "Not implemented");
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC1155Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() 
    public virtual 
    onlyOwner
    {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC1155Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() 
    public virtual 
    onlyOwner
    {
        _unpause();
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155) {
        
        for (uint256 i = 0; i < ids.length; ++i) {
            uint tokenId = ids[i];
            // Create Rewards Distribution contract for the node if it does not exist and minting(redundant check ?)
            if(listRewardMgr[tokenId] == address(0) && from == address(0)) {
                listRewardMgr[tokenId] = address(new RewardMgr(address(this), msg.sender, tokenId));
            }

            // Create DAO for the node if it does not exist
            if(listDao[tokenId] == address(0) && from == address(0)){
                listDao[tokenId] = address(new LightWorkerDao(address(this), msg.sender, listRewardMgr[tokenId], tokenId));
                //LightWorkerDao(listDao[tokenId]).addWorker(to);
                setApprovalForAll(listDao[tokenId], true);
            }
            _addTokenID(tokenId);

            // Remove if balance falls to zero
            if(from != address(0) && balanceOf(from, tokenId) == 0) {
                LightWorkerDao(listDao[tokenId]).removeWorker(from);
            }
            // Add if balance is greater than zero
            if(to != address(0) && balanceOf(to, tokenId) > 0) {
                LightWorkerDao(listDao[tokenId]).addWorker(to);
            }
        }
    }

    function getRewardMgr(uint tokenID)
        public
        view
        returns (address)
    {
        return listRewardMgr[tokenID];
    }

    function getLightWorkerDao(uint tokenID)
        public
        view
        returns (address)
    {
        return listDao[tokenID];
    }
    // Token ID enumeration
    function _addTokenID(uint tokenID)
        internal
    {
        if(!isTokenID[tokenID]) {
            tokenIDs.push(tokenID);
            isTokenID[tokenID] = true;
        }
    }
    
    function getTokenIDs()
        public
        view
        returns (uint256[] memory)
    {

        uint256[] memory _tokenIDs = new uint256[](tokenIDs.length);

        for (uint256 i = 0; i < tokenIDs.length; ++i) {
            _tokenIDs[i] = tokenIDs[i];
        }
        return _tokenIDs;
    }
    
    function getTokenOperator(uint tokenId) public returns (address) {
        address operator =  LightWorkerDao(listDao[tokenId]).getOperator();
        return operator;
    }
}
