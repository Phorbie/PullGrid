# Printing

The generator's zip contains every part as an STL, already oriented for printing and split to fit your bed. File names carry the quantity: `09-bracket-x4.stl` means print four.

## Material and settings

**PETG or PETG-GF.** Under-sink cabinets get warm and humid, and the parts carry weight for years. PLA creeps under steady load, so avoid it for the base and plates.

| Setting | Value |
|---|---|
| Layer height | 0.2 mm |
| Walls | 4 (5 for the base and printed rails, which hold screws) |
| Infill | 25% gyroid |
| Supports | None needed |
| Brim | Optional on the long base and rail pieces if your bed is fussy |

Everything is oriented for you: plates print face-down, top rails print cap-down, brackets print door-side-down. Don't rotate them.

## What you'll print

![A base piece: floor with drain slots, slide cheeks, tie-rod beads and the board groove](img/part-base.png)

| Part | What it does |
|---|---|
| **Base** (usually 3 pieces) | The tray the slides screw to. Grooves hold the bottom of the boards; beads along each side carry the tie rods |
| **Front plate** (3 pieces) | Carries the door brackets. An open frame in door-mount mode, a solid face with finger slots if you keep the door hinged |
| **Rear plate** (3 pieces) | Open frame with grooves for the back of the boards |
| **Top rail** (3 pieces per panel) | Caps the boards and ties the plates together at the top |
| **Door bracket** (4 per door) | Door-mount mode only |
| **Bowtie keys** | Glue into the plate seams |
| **Floor rails** | Only if you chose printed rails |

![A front plate piece in door-mount mode: open frame with bracket pads](img/part-front.png) ![A door bracket with slotted screw holes](img/part-bracket.png)

## openGrid boards

PullGrid doesn't print the panels itself: you print standard **openGrid** boards from [openGrid's own files](https://www.printables.com/model/1214361-opengrid-walldesk-mounting-framework-and-ecosystem), so every openGrid snap and accessory fits exactly. The generator's **openGrid boards** list gives the sizes in cells (wide × tall) and how many of each.

- Use **Full** boards: they're 6.8 mm thick and usable from both sides.
- **Lite** boards (4 mm) work if you set *Board type* to Lite, but only one side takes accessories.
- You'll also need openGrid's connector pegs for the seams between boards.

## Test print first

PullGrid is in beta, so before printing about a kilo of plastic:

1. **Print `base_1` only.**
2. **Hold a slide against the cheek.** The inner member should sit flat, and its holes should land on solid plastic. Drive one screw and check it holds.
3. **Push an openGrid board into the groove.** It should slide in with light friction, not rattle and not jam.
4. **Push your threaded rod through the bead.** It should pass freely.

If the board is too tight or loose, your printer runs a little over or under size. Adjust your slicer's XY compensation, or open an [issue](https://github.com/Phorbie/PullGrid/issues) with what you found: that's exactly the feedback the project needs right now.

## How much plastic

The generator's **Print** line estimates the total. For a typical 11″ × 24″ × 22″ cabinet with a mounted door it's roughly 1 kg of PETG. Printed rails add about a fifth more.
