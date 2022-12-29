/// Module of a Fixed Price Sale `Market` type.
///
/// It implements a fixed price sale configuration, where all NFTs in the sale
/// inventory get sold at a fixed price.
///
/// NFT creators can decide if they want to create a simple primary market sale
/// or if they want to create a tiered market sale by segregating NFTs by
/// different sale segments (e.g. based on rarity).
///
/// To create a market sale the administrator can simply call `create_market`.
/// Each sale segment can have a whitelisting process, each with their own
/// whitelist tokens.
module nft_protocol::fixed_price {
    // TODO: Consider if we want to be able to delete the launchpad object
    // TODO: Remove code duplication between `buy_nft_certificate` and
    // `buy_whitelisted_nft_certificate`
    use sui::balance;
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;

    use nft_protocol::inventory::{Self, Inventory};
    use nft_protocol::listing::{Self, Listing, WhitelistCertificate};

    struct FixedPriceMarket<phantom FT> has key, store {
        id: UID,
        price: u64,
    }

    struct Witness has drop {}

    // === Init functions ===

    public fun new<FT>(
        price: u64,
        ctx: &mut TxContext,
    ): FixedPriceMarket<FT> {
        FixedPriceMarket {
            id: object::new(ctx),
            price,
        }
    }

    /// Creates a `FixedPriceMarket<FT>` and transfers to transaction sender
    public entry fun init_market<FT>(
        price: u64,
        ctx: &mut TxContext,
    ) {
        let market = new<FT>(price, ctx);
        transfer::transfer(market, tx_context::sender(ctx));
    }

    /// Creates a `FixedPriceMarket<FT>` on `Inventory`
    public entry fun create_market_on_inventory<FT>(
        inventory: &mut Inventory,
        price: u64,
        ctx: &mut TxContext,
    ) {
        let market = new<FT>(price, ctx);
        inventory::add_market(inventory, market);
    }

    /// Creates a `FixedPriceMarket<FT>` on `Listing`
    public entry fun create_market_on_listing<FT>(
        listing: &mut Listing,
        inventory_id: ID,
        price: u64,
        ctx: &mut TxContext,
    ) {
        let market = new<FT>(price, ctx);
        listing::add_market(listing, inventory_id, market, ctx);
    }

    // === Entrypoints ===

    /// Permissionless endpoint to buy NFT certificates for non-whitelisted sales.
    /// To buy an NFT a user will first buy an NFT certificate. This guarantees
    /// that the slingshot object is in full control of the selection process.
    /// A `NftCertificate` object will be minted and transfered to the sender
    /// of transaction. The sender can then use this certificate to call
    /// `claim_nft` and claim the NFT that has been allocated by the slingshot
    public entry fun buy_nft<C, FT>(
        listing: &mut Listing,
        inventory_id: ID,
        market_id: ID,
        wallet: &mut Coin<FT>,
        ctx: &mut TxContext,
    ) {
        listing::assert_is_live(listing);
        listing::assert_inventory_is_not_whitelisted(listing, inventory_id);

        buy_nft_<C, FT>(
            listing,
            inventory_id,
            market_id,
            wallet,
            ctx,
        )
    }

    /// Permissioned endpoint to buy NFT certificates for whitelisted sales.
    /// To buy an NFT a user will first buy an NFT certificate. This guarantees
    /// that the slingshot object is in full control of the selection process.
    /// A `NftCertificate` object will be minted and transfered to the sender
    /// of transaction. The sender can then use this certificate to call
    /// `claim_nft` and claim the NFT that has been allocated by the slingshot
    public entry fun buy_whitelisted_nft<C, FT>(
        listing: &mut Listing,
        inventory_id: ID,
        market_id: ID,
        wallet: &mut Coin<FT>,
        whitelist_token: WhitelistCertificate,
        ctx: &mut TxContext,
    ) {
        listing::assert_is_live(listing);
        listing::assert_inventory_is_whitelisted(listing, inventory_id);
        listing::assert_whitelist_certificate_market(market_id, &whitelist_token);

        listing::burn_whitelist_certificate(whitelist_token);

        buy_nft_<C, FT>(
            listing,
            inventory_id,
            market_id,
            wallet,
            ctx,
        )
    }

    fun buy_nft_<C, FT>(
        listing: &mut Listing,
        inventory_id: ID,
        market_id: ID,
        wallet: &mut Coin<FT>,
        ctx: &mut TxContext,
    ) {
        let market =
            listing::market<FixedPriceMarket<FT>>(listing, inventory_id, market_id);

        let funds = balance::split(coin::balance_mut(wallet), market.price);
        listing::pay(listing, funds, 1);

        listing::redeem_nft_internal_and_transfer<
            C, FixedPriceMarket<FT>, Witness
        >(
            Witness {},
            listing,
            inventory_id,
            tx_context::sender(ctx)
        );
    }

    // === Modifier Functions ===

    /// Permissioned endpoint to be called by `admin` to edit the fixed price
    /// of the launchpad configuration.
    public entry fun set_price<FT>(
        listing: &mut Listing,
        inventory_id: ID,
        market_id: ID,
        new_price: u64,
        ctx: &mut TxContext,
    ) {
        let market = listing::market_mut<FixedPriceMarket<FT>>(
            listing, inventory_id, market_id, ctx
        );
        market.price = new_price;
    }

    // === Getter Functions ===

    /// Get the market's fixed price
    public fun price<FT>(market: &FixedPriceMarket<FT>): u64 {
        market.price
    }
}
