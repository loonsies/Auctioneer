# Auctioneer
### Auction House Bidding Tool for Ashita

Auctioneer is an addon for Ashita that enhances your auction house experience. It allows you to perform auction house actions via commands, display sales information, and customize your AH interface.

---

## Features
- **Command-based Bidding and Selling**  
  Perform AH transactions quickly using simple commands.
- **Sales Information Display**  
  View sales details in a customizable text object when opening the AH menu.
- **Inbox/Outbox Access**  
  Open your delivery boxes directly with commands.

---

## Commands

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
- **Open AH Menu:** `ah`  
- **Clear Sold/Unsold Status:** `ah clear`  

### Text Object Customization
Control what information appears in the AH sales text object:  
- `ah show` or `ah hide`  
  Customize display options using:  
  - `timer`: Countdown/up timer.  
  - `date`: Auction end or sale/return date and time.  
  - `price`: Asking price.  
  - `empty`: Show/hide empty slots.  
  - `slot`: Display normalized slot numbers. 

---

## Additional Notes
- Check the settings file for further customization options.
- After game updates or maintenance, ensure Ashita's resources are updated for new items.

---

## To-Do List
1. Expand delivery box functionality to other zones (e.g., Mog House).  
2. Block sell confirmation when injecting sell packets (occurs within the sell menu).  
3. Adjust delays for smoother performance.
