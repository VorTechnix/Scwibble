## Scope

Scwibble, at its core, is a utility to set and sync backgrounds between Desktop Environment (DE), Desktop Manager (DM) and Screen Locker (SL). While initially developed for KDE Plasma DE to sync background with LightDM the hope is that it evolves beyond that into a tool that will act as a universal background setting and synchronizing utility that will work across many/most DEs, DMs and SLs.

To meet this goal a lightweight script library for detecting what the active DE, DM and SL are will need to be found or made. If one must be made it should be treated as a bundled project with separate license etc.

## Roadmap

- [ ] Implement proper directory tree with main script in a `./bin` and subscripts in `./lib`
```
/etc/conf/
└── scwibble.conf
/usr/local/
├── bin/
│   └── scwibble <-- Start script
└── lib/
    ├── <DE, DM, SL autodetect>/
    │   ├── subscript1
    │   └── ...
    └── scwibble/
        ├── subscript1
        └── ...
```
- [ ] Interactive Mode
    - Probably via python loop
- [ ] Better flag handling
    - Same character short flags like `-ss` for `--setsync` instead of `-b`
    - Option entry like `-Slm` to set *only* SL and DM
- [ ] Information display
    - Location of current background
    - Active DE, DM and SL
        - Active greeter if possible
    - Scwibble settings
    - More detailed helps
- [ ] Modular system for adding support scripts for DEs, DMs and SLs
- [ ] Individual syncing and setting of SL (KScreenLocker) and DM (LightDM) on a per-user basis.
    - Will require `user-background = true` to be set in greeter conf.
    - May want to implement greeter autodetection and auto-user-background enabling.
