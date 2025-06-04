# Auctioneer
### Auction House Bidding Tool for Ashita

Auctioneer is an addon for Ashita that enhances your auction house experience. It allows you to perform auction house actions via commands, display sales information, and customize your AH interface.

---

## Features
- **Command-based Bidding and Selling**  
  Perform AH transactions quickly using simple commands.
- **Inbox/Outbox Access**  
  Open your delivery boxes directly with commands.

---

## Commands

### Auctioneer
- **Toggle UI:** `ah`
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

## Additional Notes
- Check the settings file for further customization options.
- After game updates or maintenance, ensure Ashita's resources are updated for new items.
