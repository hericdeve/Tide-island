# 🐾 Tide Island — Pixel Pet Design Guide

Welcome to the **Pixel Pet Extensibility System**! This guide walks you through designing, animating, and registering custom pets and accessories for your Tide Island notch companion.

---

## 🎨 1. The 16×16 ASCII Sprite Format

All pets are defined in `PetCatalog.js` using human-readable **16×16 string arrays**. Each character in the 16-row grid maps directly to a color in the pet's palette:

| Character | Role | Purpose |
|---|---|---|
| `.` | Transparent | Empty space around your pet |
| `X` | Outline | Outer silhouette / shadow boundary |
| `1` | Primary Body | Main coat, fur, or scale color |
| `2` | Secondary Body | Chest, muzzle, belly, or inner ears |
| `3` | Shadow / Accent | Muscle shadows, tail rings, or darker coat patches |
| `E` | Eyes | Pupil / Eye color |
| `W` | Highlight | Eye gleam / Shiny glint |
| `B` | Blush | Rosy cheek circles |
| `A` | Special Accent | Collars, horns, bells, sparks, or bows |

### Example 16×16 Grid:
```javascript
[
    "................",
    "....X.....X.....",
    "...X1X...X1X....",
    "...X11XXX11X....",
    "..X111111111X...",
    "..X1E11111E1X...",
    "..X1W12221W1X...",
    "..X1B12221B1X...",
    "...XX11111XX....",
    "....XAAAAAX.....",
    "...X1122211X..X.",
    "..X111222111XX1X",
    "..X111222111X11X",
    "..X11111111111X.",
    "...X1X...X1X.X..",
    "....XX....XX...."
]
```

---

## 🐾 2. Designing a New Pet

To add a new pet, open `qml/widgets/pixel_pet/PetCatalog.js` and add an entry to the `PETS` dictionary:

```javascript
"panda": {
    id: "panda",
    name: "Bao",
    species: "Giant Panda",
    bio: "A peaceful, bamboo-loving bear who rolls around happily.",
    favoriteFood: "carrot", // or "berry", "meal", etc.
    palette: {
        ".": "transparent",
        "X": "#111827",
        "1": "#f8fafc", // White body
        "2": "#1e293b", // Black arms, ears, eye patches
        "3": "#cbd5e1", // Fur shadow
        "E": "#0f172a",
        "W": "#ffffff",
        "B": "#fb7185", // Blush
        "A": "#10b981"  // Green bamboo leaf
    },
    frames: {
        idle: [ /* 2 frames: breathing or blinking */ ],
        walk: [ /* 2 frames: stepping feet */ ],
        happy: [ /* 2 frames: jumping or rolling */ ],
        sleep: [ /* 1-2 frames: sleeping curled up */ ],
        eat: [ /* 2 frames: chewing animation */ ],
        stressed: [ /* 1 frame: sweat drop or worried eyes */ ],
        jamming: [ /* 2 frames: head bobbing up and down */ ]
    },
    speech: {
        greetings: ["*snuffle*", "Hello friend!", "Got bamboo?"],
        eating: ["*crunch crunch* So delicious!", "Best bamboo ever!"],
        petting: ["*soft bear grumbles* ❤️", "Soft fur, warm hugs."],
        music: ["Rolling with the beat! 🎵", "Groovy vibrations!"],
        stressed: ["Too much processing! 💧", "Need a nap in the shade!"]
    }
}
```

---

## 🎩 3. Designing Custom Accessories

Accessories are **16×8 pixel slices** placed over the top of the pet's head. You can add hats, glasses, masks, or headwear:

```javascript
"party_hat": {
    id: "party_hat",
    name: "Party Hat",
    icon: "󰍢",
    palette: {
        "X": "#881337",
        "1": "#f43f5e",
        "2": "#38bdf8",
        "3": "#facc15"
    },
    frames: [
        [
            ".......XX.......",
            "......X33X......",
            ".....X1111X.....",
            "....X222222X....",
            "...X11111111X...",
            "..X2222222222X..",
            ".XXXXXXXXXXXXXX.",
            "................"
        ]
    ]
}
```

---

## 🍎 4. Adding Custom Foods

Foods can be added to `FOODS` in `PetCatalog.js`:

```javascript
"bamboo": {
    id: "bamboo",
    name: "Fresh Bamboo",
    icon: "󰄛",
    nutrition: 35,
    favBonus: 15,
    crumbColor: "#10b981"
}
```

---

## 💡 Pro Tips for Pixel Art
1. **Integer Scaling**: All pixels render with `imageSmoothingEnabled = false` (nearest-neighbor), so your sprites will always look sharp and authentic on 4K, 1440p, or 1080p screens.
2. **Horizontal Flipping**: You only need to draw walking right! The engine automatically inverts `flipX` when the pet turns around to walk left.
3. **Head Bobbing**: In `jamming` state, frame 1 drops down 1 pixel to give that classic beat-bobbing feel.
4. **Favorites**: When you feed a pet their `favoriteFood`, they earn extra bonus XP, extra happiness, and unique dialogue!
