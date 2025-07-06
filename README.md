# Auctioneer
### AH Tool for Ashita

Auctioneer is an addon for Ashita v4 aiming to make auction house usage easier.

***DISCLAIMER :***

**While I tried my best to keep the addon safe to use, you are still sending packets outside of the normal conditions they're supposed to be sent in.
Things like remote mailbox/AH access or slots clearing is not and will never be 100% safe. Outgoing packets are throttled to be sent every 8 seconds and queued if necessary.
The rest depends on your usage. You are responsible for the usage of this addon.**

---

## Features
- **Command-based Bidding and Selling**  
  Perform AH transactions quickly using simple commands.
- **UI for transactions and sales monitoring**  
  You can search for items using their names, filter by category (more filters to come), or preview the item directly in the UI. You can also monitor your sales from there.
- **Inbox/Outbox Access**  
  Open your delivery boxes directly with commands.
- **Remote AH access and slots clearing**  
  You can clear your slots remotely, as well as accessing the auction house remotely (like with ahgo)

---

## Commands

### Auctioneer
- **Toggle UI:** `auctioneer|ah`
- **Show Auctioneer UI:** `ah show`
- **Hide Auctioneer UI:** `ah hide`

### Buying and Selling
- **Buy Items**  
  `buy [item name] [stack] [price]`  
  Example: `buy Prism Powder stack 1000`  
  Purchases an item on the auction house.

- **Sell Items**  
  `sell [item name] [stack] [price]`  
  Example: `sell Prism Powder 1 2000`  
  Lists an item for sale. Open the AH once after logging in or loading the addon.

#### Parameters:
- `[item name]`: Auto-translate, short, or full names accepted (no quotes needed).  
- `[stack]`: Use `stack`, `single`, `1`, or `0`.  
- `[price]`: Accepts formats like `100000`, `100,000`, or `100.000`.

---

### Delivery Box Commands
- **Open Inbox:** `inbox` or `ibox`  
- **Open Outbox:** `outbox` or `obox`  

---

### Auction House Menu Commands
- **Open AH Menu:** `ah menu`  
- **Clear Sold/Unsold Status:** `ah clear`

---

## Credits & Thanks

- [Ivaar](https://github.com/Ivaar) for the [original addon](https://github.com/Ivaar/Ashita-addons/tree/master/Auctioneer)
- [mousseng](https://github.com/mousseng) for some functions i used, mainly for item preview
- [ThornyFFXI](https://github.com/ThornyFFXI) for all their unvaluable help!
