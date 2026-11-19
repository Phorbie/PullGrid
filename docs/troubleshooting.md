# Troubleshooting

## Generator messages

| Message | What it means | What to do |
|---|---|---|
| **Doesn't fit** | After the rails, slides, hinges and clearances, there isn't room for even one openGrid cell (28 mm) in some direction | Re-measure the opening. In keep-hinged mode, try mounting the door instead, which frees the hinge space |
| **The pull-out is narrow** | It fits, but it's under 100 mm wide inside | Fine for spices and sprays. Consider fewer panels |
| **Shallower than the shortest standard slide** | The cabinet is too shallow for a 10″ / 250 mm slide | Check the depth measurement. Shorter slides exist but aren't stocked everywhere |
| **Aluminum angle won't reach the slides** | Your bottom rail is tall, so the slides sit higher than the tallest stock angle reaches | Switch *Floor rails* to **Printed** |
| **That door is too thin** | Door mount needs at least 15 mm of door for the bracket screws | Keep the door hinged, or use shorter screws and accept less grip |
| **Some parts are bigger than your bed** | Shouldn't happen with auto pull-outs | Check *Print bed*, or let *Pull-outs* go back to auto |

The report also lists what each obstacle cost, for example "Hinge 1: narrowed the frame from the left". That tells you which measurement to double-check.

## Building and installing

**The slides bind or feel rough.** The rails are too close together, not parallel, or not square to the front. Unscrew one rail and let the pull-out position it: clip it in, run it back and forth a few times, then re-mark and re-screw. If they're still tight, raise *Slide thickness* by 0.3 mm in **Hardware & clearances** and reprint the base.

**A board rattles in its groove, or won't go in.** Your printer prints slightly under or over size. Adjust XY compensation in your slicer, or reprint the board slightly scaled. See [Test print first](printing.md#test-print-first).

**The pull-out racks (leans) when you pull it.** Tighten the tie rods evenly, a quarter turn at a time. Check the top rails are seated fully between the plates.

**The tie rod is too short to get a nut on.** The cut length includes room for a washer and nut at each end. Cut a new rod to the length in the **Cut** list, measured carefully.

**The door's gaps are uneven.** Use the slots: up and down at the plate screws, side to side at the door screws. If that isn't enough, the rails aren't square to the cabinet front.

**The door hits the face frame before closing.** Your face frame is deeper than the default 3/4″ (19 mm). Measure it and set *Face frame depth* in **Advanced**, then reprint the brackets.

**Something else?** Open an [issue on GitHub](https://github.com/Phorbie/PullGrid/issues) with your settings link (the generator's **Copy link** button) and a photo.
