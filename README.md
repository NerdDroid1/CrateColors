# Crate Colors (Project Zomboid Build 42)

Paint any world container with a full-RGB color. Requires a paintbrush + a can of paint.

## Folder layout
```
CrateColors/                        <- goes in  %UserProfile%\Zomboid\Workshop\
├── preview.png                     256x256 Steam Workshop thumbnail
├── workshop.txt                    title / description / tags for the uploader
└── Contents/mods/CrateColors/
    ├── common/                     required by B42 (empty is fine)
    └── 42/
        ├── mod.info                id=CrateColors
        ├── poster.png  icon.png
        └── media/lua/
            ├── shared/CrateColors_Shared.lua            config, paint detection, tint + modData
            ├── shared/TimedActions/ISPaintContainerAction.lua
            ├── client/CrateColors_Client.lua            right-click menu, server->client sync
            └── client/CrateColors_UI.lua                color dialog (HSB picker + hex)
```

## Test locally
1. Copy the whole `CrateColors` folder to `C:\Users\<you>\Zomboid\Workshop\`.
2. Launch PZ (B42) > Mods > enable **Crate Colors**.
3. In a sandbox save, use debug mode or loot a Paintbrush + Paint can, right-click any crate.

## Upload
Main menu > **Workshop** > Create and update items > select CrateColors > follow the wizard.
After upload, copy the Workshop ID into your server's `WorkshopItems=` and add `CrateColors` to `Mods=`.

## Tuning
Edit `CrateColors.Config` at the top of `CrateColors_Shared.lua`
(paint per coat, action time, brush requirement, free paint removal).
