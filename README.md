# LanceBags-WoTLK-3.3.5
**LanceBags** backport with improved UI and functions for 3.3.5 WoTLK client.

![wow_CNgtiMLTXH](https://user-images.githubusercontent.com/74269253/229909788-3782f7b8-a995-4095-b997-37bf895675b6.png)


## 📦 Download & Installation

1. Click the green `Code` button at the top of this page, then select  
   **[Download ZIP](https://github.com/Sattva-108/LanceBags/archive/refs/heads/main.zip)**

2. Extract the downloaded `.zip` file. You’ll get a folder named:  
   **`LanceBags-main`**

3. Move the `LanceBags-main` folder into your WoW AddOns directory:  
   `World of Warcraft\Interface\AddOns\`

4. Rename the folder to exactly:  
   **`LanceBags`**

✅ Done! The addon should now appear in your in-game addon list.

- _**(Optional)**_ - Download supported extra-modules for LanceBags - [LanceBags-WoTLK-3.3.5-Mods](https://github.com/Sattva-108/LanceBags-WoTLK-3.3.5-Mods)


## Usage
`/lancebags` or `/lb` - chat command to open **CONFIGURATION panel** for LanceBags.
<details> <summary> More usage: </summary>
1. Enable / Change modules by selecting them in the LanceBags menu ( /lb command).
<br>
2. `Left-Click` bag icon in top-left corner to open the LanceBags configuration menu.
<br>
3. `Right-click` on any of your current bags to automatically sort bag space out of it (to another bags), so you can replace it by new one.
<br>
4. `Left-Click` an item in your bag and drag to desired catergory title within a bag, to assign it to another category.
</details>

## Key Features

* [cite_start]Smart filters dispatch items into sections for Junk, Quest Items, Equipment, Trade Goods, Consumables, and more. [cite: 8]
* [cite_start]Support for Blizzard's Gear Manager item sets. [cite: 8]
* [cite_start]Smart item sorting within each section and intelligent section layout. [cite: 9]
* [cite_start]A unified "One Bag" view option. [cite: 96]
* [cite_start]Customizable Skins to change fonts, backgrounds, and borders. [cite: 42]
* [cite_start]Item Level display on item icons. [cite: 50]
* [cite_start]An integrated Bag Menu for quick access to functions. [cite: 51]
* [cite_start]A "Sell Junk" button that appears at vendors. [cite: 111, 115]
* [cite_start]Dynamic gold summary tooltip showing gold across your characters. [cite: 119]

## Changelog
<details> <summary> Click to see the full Changelog </summary>

* [cite_start]**June 4, 2023:** Added Experimental Masque support. [cite: 37]
* [cite_start]**June 3, 2023 (#8):** Fixed conflict with Immersion addon. [cite: 38]
* **June 3, 2023 (#7):**
    * Core: Small Bag Layout improvements; [cite_start]Fix Heartstone being recognized as "Junk". [cite: 39]
    * [cite_start]Skins: Added Reset Button, font Color Option, more Font Sizes, and made Title Font changeable. [cite: 39]
    * [cite_start]ItemLevel: Added Text Configuration for Font, Position, Size, and Color. [cite: 39]
* [cite_start]**May 31, 2023:** Added new feature: Skins. [cite: 42]
* **May 9, 2023:** Fixed inability to move bag in Manual mode; Added Alt+Left click to toggle anchoring modes; Added Reset Position and Toggle Anchor options to Bag Menu; [cite_start]Added option to swap mouse clicks for bag menu. [cite: 43, 44, 45, 46, 47]
* **May 2, 2023:** Disabled TidyBags by default; [cite_start]Added support for external plugins. [cite: 48, 49]
* [cite_start]**April 17, 2023:** Added item level plugin. [cite: 50]
* **April 15, 2023:** Added Bag Menu with right-click for options and left-click for a dropdown menu; [cite_start]Adjusted default positions and fixed visual bugs. [cite: 51, 52, 53, 55, 56]
* [cite_start]**April 4, 2023:** Addon backported and ready for release. [cite: 57]
</details>

## Project History & Original Philosophy
<details> <summary> Click to see the project's history and notes from the original author </summary>

[cite_start]This version of LanceBags is a fork of AdiBags, with identifiers renamed to avoid collisions with the original addon. [cite: 1]

The following are notes from the original author, Adirelle, regarding the design philosophy of AdiBags/LanceBags.

**Things that likely will not be implemented:**

* [cite_start]**Anything else than the existing "all-in-one" views:** The addon was built and optimized around this concept. [cite: 10, 11]
* [cite_start]**Anything that requires scanning item tooltips:** This is CPU-intensive and would raise the complexity of the addon significantly. [cite: 12, 13] [cite_start]This includes detecting bind status, known/unknown recipes, or class restrictions. [cite: 14, 15]
* [cite_start]**Guild Bank:** To avoid messing up a guild's manual organization, guild bank support will not be implemented. [cite: 16, 17, 18, 19]
* [cite_start]**Alt bags and bank:** The original author noted that LanceBags is not intended as an alt-bank viewer and suggested other addons for that purpose. [cite: 20, 21] *(Note: This is a feature we are now adding to this modified version).*
* [cite_start]**Bag Skinning:** "Who need it anyway ?" [cite: 22] *(Note: This feature has been added to this modified version).*
* [cite_start]**Comprehensive in-game filter editor:** The author preferred to focus on smart filters with few options to avoid excessive development effort. [cite: 23, 24]

</details>

## Credit
- Credit to **Adirelle** for creating the original AdiBags/LanceBags.
- This project is a backport and modification of code from [LanceBags](https://github.com/AdiAddons/LanceBags).
