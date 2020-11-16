# kOS-Launch-Scripts

## Installation

To install just add all files in the "kOS---Scripts"-folder to a "$your_KSP_install_folder/Ships/Script"-folder.

## Easy first use

Running "/boot/default.ks" in game loads all libraries in "/libraries" to your **kOS** core and lets you run one of the scripts in "/launch".f

So if you set "default.ks" as your starting program your **kOS** console will greet you with a promt to choose one of the included launchfiles.

### Launch.ks

This basic script shows how you can use the built in libraries by providing a simple yet functional example of a launch script.
It sets a mission name which is purely cosmetic.
It starts the function p_Launch() to launch your rocket into orbit.
Then it exits the script in a safe state by calling the Quit() function.

## The runF.ks Script

The "runF.ks" script allows to run any library function from the **kOS** console, a feature which is still missing from kOS.

For example you can execute `run runf("p_orb_burn").` to run the `p_orb_burn()` function from "LaunchLib.ks" and execute the next maneouver node.

