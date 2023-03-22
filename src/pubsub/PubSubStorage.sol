pragma solidity 0.8.16;

import {PublishStatus} from "src/pubsub/interfaces/IPubSub.sol";

import {SubscriptionStatus} from "src/pubsub/interfaces/IPubSub.sol";

import {TelepathyRouter} from "src/amb/TelepathyRouter.sol";

contract PubSubStorage {
    /*//////////////////////////////////////////////////////////////
                           PUBLISHER STORAGE
    //////////////////////////////////////////////////////////////*/

    TelepathyRouter telepathyRouter;

    mapping(bytes32 => PublishStatus) public eventsPublished;

    /*//////////////////////////////////////////////////////////////
                           SUBSCRIBER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(bytes32 => SubscriptionStatus) public subscriptions;

    /// @dev This empty reserved space is put in place to allow future versions to add new variables
    /// without shifting down storage in the inheritance chain.
    /// See: https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#storage-gaps
    uint256[50] private __gap; // TODO reduce by 1 for each
}
