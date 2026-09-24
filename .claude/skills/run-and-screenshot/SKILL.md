---
name: run-and-screenshot
description: Use when a UI change in DompetKu needs to be visually verified before reporting it done — launches the app and captures its visual state.
---

# Run & Visually Verify DompetKu

Never claim a UI change looks right without seeing it rendered. Use this
procedure before reporting UI work complete.

1. **Pick a target.** `flutter run -d chrome` is the fastest path to a
   visual check (renders as a normal web page, works with browser
   automation). Use `flutter run -d windows` only when the change is
   platform-specific to desktop behavior chrome can't exercise (e.g.
   window sizing, native file dialogs).
2. **Launch it** in the background so you can keep working:
   ```bash
   flutter run -d chrome --web-port=8765
   ```
   Wait for the "Flutter run key commands" banner and the app URL in
   the output before trying to interact with it.
3. **Navigate and capture.** If the `claude-in-chrome` skill/tools are
   available in this session, use them to open the app URL, navigate to
   the changed screen, and take a screenshot. If browser automation
   isn't available, ask the user to look at the running app and
   describe or screenshot what they see — don't guess at the visual
   result from code alone.
4. **Compare against the approved mockup** when the change is part of the
   redesign. Open `docs/design/dompetku-redesign-mockup.html` in the
   browser too, find the screen by name, and go through the plan task's
   visual checklist item by item:
   - section order
   - large title and nav bar
   - card shapes and radii
   - which card uses the blue hero gradient
   - segmented control vs chip tabs
   - "+" placement
   - empty state

   Report every difference you see, not just "looks right".

   Hosting notes for Windows with Git Bash:
   - Start `flutter run` in the background with `&`, and wait with
     `until grep -q "Debug service listening" <log>; do sleep 3; done`.
   - Hot reload can't be sent once the launching shell returns. After a
     code change, kill the port's PID (`netstat -ano | grep :8765`, then
     `taskkill //F //PID <pid>`) and relaunch.
   - Afterwards, revert the regenerated
     `linux/ macos/ windows/` plugin registrant files with
     `git checkout -- linux macos windows`. Only their line endings change.
5. **Check the golden path and one edge case** relevant to the change
   (e.g. empty state, long text, dark mode via the app's theme toggle)
   — not just the happy path.
6. **Stop the app** when done verifying (Ctrl+C / stop the background
   process) rather than leaving it running.
7. **Report honestly.** If you could not actually view the rendered UI
   (no browser automation, no screenshot), say so explicitly instead of
   claiming the change was visually verified.
