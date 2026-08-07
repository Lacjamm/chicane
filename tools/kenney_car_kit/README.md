# Kenney Car Kit (vendored subset)

Source: "Car Kit" by Kenney — https://kenney.nl/assets/car-kit
License: Creative Commons CC0 (see License.txt) — no attribution required,
credit appreciated: "Kenney.nl".

Only the 7 GLB bodies used by `tools/convert_car_models.gd` are vendored
here (plus the shared palette texture). Regenerate the per-skin model
folders + distributable pack with:

    godot --headless --path chicane3d --script ../tools/convert_car_models.gd

then zip `chicane3d/assets/models/**` (forward-slash entry names, zip name
matching `chicane_*_models_*.zip`) to rebuild the distributable pack.
