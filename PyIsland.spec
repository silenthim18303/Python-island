# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['E:\pyisland\Python-island\pyisland2.py'],
    pathex=['E:\pyisland\Python-island'],
    binaries=[],
    datas=[
        ('E:\pyisland\Python-island\assets', 'assets'),
        ('E:\pyisland\Python-island\method', 'method')
    ],
    hiddenimports=['win10toast', 'win11toast', 'wmi', 'windows_bluetooth_watcher'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='PyIsland',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    uac_admin=True,
    icon=['E:\pyisland\Python-island\assets\public\icon\pyisland.ico'],
)