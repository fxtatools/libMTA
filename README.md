libMTA: Technical Analysis Tools for MetaTrader4 Platforms
==========================================================


Availability: [fxtatools/libMTA at GitHub](https://github.com/fxtatools/libMTA/)

## Installation

The following walkthrough will illustrate how to create a Git repository in the MQL4 source directory, then checking out the libMTA sources into that directory.

**Known Limtiation:** This approach may represent something of a crude method for installation, as it would permit exactly one project at any one time, in the MQL4 source directory.

### Git

This assumes [Git](https://git-scm.com) is installed on the client system.

Git is available for Microsoft Windows platforms, with [Tortoise Git](https://tortoisegit.org) and [Git for Windows](https://gitforwindows.org) as well as with MSYS2.

MSYS2 can be installed on Microsoft Windows platforms using the [Chocolatey package management system](https://chocolatey.org) ([MSYS2](https://community.chocolatey.org/packages/msys2/); [Chocolatey GUI](https://community.chocolatey.org/packages/ChocolateyGUI)). Once MSYS2 is installed, then using BASH or a preferred command line shell in the MSYS2 `mintty` terminal, Git can be installed with the shell command, `pacman-install git`.

### Locating the MQL4 Directory

An individual FX trading broker will often provide a customied build of the [MetaTrader4](https://www.metatrader4.com/) platform. This can typically be located by searching for "metatrader4" within pages at the broker's web site.

Once the MetaTrader4 client terminal is installed, the MetaEditor GUI can be started from within the MetaTrader4 terminal. This GUI will provide an interface to the MQL4 compiler, for building these source files for use with MetaTrader4.

Once the MetaEditor GUI is initialized, the hotkey `Ctrl+D` can be used to display the MetaEditor files navigator. After right-clicking on any file or directory in the files navigator then selecting the context menu item, `Open Folder`, a Windows Explorer window will be created at the location of the filesystem object. This would then indicate the pathname of the MQL4 folder for the individual client terminal installation under the user's Microsoft Windows account.

Navigating to the top MQL4 folder in this installation, the following subdirectories should be visible: `Experts`, `Files`, `Images`, `Indicators`, `Libraries`, `Presets`, `Projects,` `Scripts`, `Shared Projects`.

Once having located this folder, a new Git repository can be created using the following shell command,  or with the Tortoise Git _context menu_ for Windows Explorer.

```bash
git init
```

After creating a Git repository in this MQL4 folder, the libMTA source repository can be added as a git remote, using Tortoise Git or the Git shell tools e.g:

```bash
git remote add libmta https://github.com/fxtatools/libMTA.git
```

After the Git remote is added, the source code for the `main` libMTA branch can be retrieved with the following shell command, or the Tortoise Git GUI.

```bash
git fetch libmta main
```

The newly retrieved libMTA sources can then be checked out into the MQL4 directory, while creating a local `main` branch with the shell command:

```bash
git switch -c main libmta/main
```

If the checkout would overwrite any existing files, Git will emit a warning before the file checkout procedure.

After the sources are checked out, Git submodules for this project directory should be initialized to the versions referenced in the libMTA sources.

```bash
git submodule init && git submodule update
```

Following this, MetaEditor can be used to compile any indicators and scripts.

## Editing MQL4 Sources

The MetaTrader4 _**MetaEditor**_ GUI provides a normal graphical user interface for editing, compiling, and debugging MQL sources.

This project also uses the [VS Code](https://code.visualstudio.com/) IDE, primarily for editing the source code of MQL class definition files.

Using VS Code, additional VS Code extensions may be installed with nicholishen's [MQL Extension Pack](https://marketplace.visualstudio.com/items?itemName=nicholishen.mql-extension-pack) ([GitHub](https://github.com/nicholishen/mql-snippets-for-VScode)). These extensions would provide additional support for _Intellisense_ in VS Code language support, as well as for syntax highlighting for MQL sources.

For C++ compiler support in VS Code, this project uses clang as installed with MSYS2 (referred above).

Intellisense is available for VS Code installations on Microsoft Windows, and may be avaialble on other platforms supported by VS Code.

## "To Do"

To allow for installing from a central source directory outside of the MQL4 directory, CMake could be supported in this project. This would require some additional scripting for configuring the installation, as well as for orchestrating the installation process with CMake, GNU Make, and the MetaEditor compiler.

## References

- Pruitt, G. (2016). Stochastics and Averages and RSI! Oh, My. In The Ultimate Algorithmic Trading System Toolbox + Website (pp. 25–76). John Wiley & Sons, Inc. https://doi.org/10.1002/9781119262992.ch2
- Kaufman, P. J. (2013). Momentum and Oscillators. In Trading Systems and Methods (5th ed.). Wiley.
- Investopedia (Technical Indicators)
- Wikipedia (Welles Wilder's ATR and ADX functions; Conventions for moving average)

## Licensing Terms

Except where otherwise noted, the source code in this repository is provided to the public under the following terms of license.

Copyright (c) 2023 Sean Champ

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
