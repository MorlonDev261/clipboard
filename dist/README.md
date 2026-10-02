# Dist

Ce dossier est l'emplacement officiel des fichiers générés prêts à partager.

Utiliser le script:

```powershell
powershell -ExecutionPolicy Bypass -File tools/collect_release_artifacts.ps1
```

Organisation:

```text
dist/
├── latest/
│   ├── android/
│   ├── windows/
│   └── web/
└── releases/
    └── <version-date>/
        ├── android/
        ├── windows/
        └── web/
```

`latest/` contient la dernière génération.  
`releases/` conserve les générations datées.
