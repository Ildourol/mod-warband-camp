/*
 * Copyright (C) 2025+ WOW Legends / Standalone Port
 * Released under GNU AGPL v3 license.
 */

// AzerothCore module script loader entry point.
// AzerothCore automatically invokes Add<module-folder-with-underscores>Scripts() on startup.

void AddWarbandCampScripts();
void AddSC_GOMove_commandscript();

void Addmod_warband_campScripts()
{
    AddWarbandCampScripts();
    AddSC_GOMove_commandscript();
}
