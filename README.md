# Auctioneer
### AH Tool for Ashita

Auctioneer is an addon for Ashita v4 aiming to make auction house usage easier.

***DISCLAIMER :***

**While I tried my best to keep the addon safe to use, you are still sending packets outside of the normal conditions they're supposed to be sent in.
Things like remote mailbox/AH access or slots clearing is not and will never be 100% safe. Outgoing packets are throttled to be sent every 8 seconds and queued if necessary.
The rest depends on your usage. You are responsible for the usage of this addon.**

---

<p align="center">
  <img width="673" style="max-width: 100%;" alt="image" src="https://github.com/user-attachments/assets/9f8bd440-a612-41b4-9368-111fe829ae51" />
  <img width="678" style="max-width: 100%;" alt="image" src="https://github.com/user-attachments/assets/f6ef6c87-0346-4479-99b6-9dbdf90aefb4" />
  <img width="752" style="max-width: 100%;" alt="image" src="https://github.com/user-attachments/assets/20cde589-0e8c-4638-9bb3-345f73d83928" />
</p>

# Features

### Auction House
- Buy and sell items directly from the UI or via commands
- View your active auction house slots
- Clear auction house slots from the UI

### Item Browser
- Browse **all in-game items** with full descriptions
- Search items by name
- Filter by:
  - Auction House category
  - Item level
  - Job

### Inventory Management
- View **all your inventories** from a single UI
- Includes Mog Garden inventory
- Mog Garden tracking feature:
  - Shows which items were added since entering Mog Garden
  - Useful for fast daily Mog Garden runs

### Customization
- Wide range of settings to tailor the experience to your preferences

### Integrations
- **Bellhop integration**
  - Buy and sell items to NPCs using items from your inventory
- **External resources**
  - Open **bg-wiki.com** or **FFXIAH** pages for any item directly from the UI
- **Market data**
  - Fetch FFXIAH price history
  - View current bazaar listings

---

# Commands

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
- [mousseng](https://github.com/mousseng) for some functions i used, mainly for item preview, inventory stuff
- [ThornyFFXI](https://github.com/ThornyFFXI) for all their unvaluable help!


