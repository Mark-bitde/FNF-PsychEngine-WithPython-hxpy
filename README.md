# FNF: Psych Engine with Python Support (via hxpy)

An experimental modification of the FNF Psych Engine written in Haxe that introduces native Python language support for modding using the Hython interpreter. 

*Note: This project is a community-driven implementation and is not affiliated with the original Psych Engine developers.*

## 🚀 Why Python?
Instead of traditional Lua or limited Haxe-scripts, this engine allows you to write your mod scripts in Python! Thanks to the embedded **hxpy** library, it runs a real, native **Embedded Python 3.13** interpreter directly inside the HaxeFlixel environment. 

This means you get full access to the Python ecosystem, native speed, and advanced features without requiring any external Python installations from your players!

## ✨ Engine Features Include:

*   **🔒 Lua-like Global Sandbox Isolation:** Thanks to custom architectural design using Python's `exec()` and native context dictionaries, every script runs in its own separate memory space. Multiple scripts can use the same callback names (`def onCreate()`, `def onUpdate()`) simultaneously without overwriting or interfering with each other.
*   **🧩 True Object-Oriented Programming (OOP):** Unlike Lua, you can write fully fleshed-out Python classes, use inheritance, encapsulation, and store object states inside custom instances for complex modcharts.
*   **📦 Zero Dependencies for Players:** Powered by Embedded Python 3.13, all necessary runtimes and libraries are packed inside `python313.zip` and binary DLLs right in the game folder. Players can download and play your mod in one click!
*   **⚡ High-Speed Context Synchronization:** The engine features a robust, type-safe data converter that pipes values (Integers, Floats, Strings, and Booleans) straight into the isolated Python dictionaries in real-time, eliminating micro-stutters and frame drops during intense note spam.
*   **🛠 Built-in Package Support:** Ready for heavy math, data parsing, or custom algorithms. You can easily bundle external libraries like **NumPy** inside the `site-packages` directory of the embedded runtime.
*   **🧼 Automatic Memory Management:** The engine automatically tracks active scripts and forces complete garbage collection on `stop()` via `.clear()` and `del` operations, preventing any progressive memory leaks on song restarts.

## 🛡️ Security & Sandboxing
Safety first! Even though the engine runs a native Embedded Python 3.13 interpreter, it is completely isolated from the user's operating system:
* **Safe Environment:** Python scripts cannot access crucial system files, execute malicious OS commands, or modify registry keys.
* **Controlled API:** Scripts are strictly limited to the Haxe/Flixel game bindings (`setHealth`, `playAnim`, `noteTween`, etc.) provided by the engine.
* **No Exploits:** Players can download and play Python-powered mods safely, knowing the runtime behaves exactly like a secure game sandbox.


This engine delivers a bulletproof, high-performance runtime for Friday Night Funkin' mods:
* **Air-Gapped Sandbox:** Heavy system modules like `subprocess`, `os`, and `shutil` are physically stripped from the embedded environment. Malicious scripts cannot execute OS commands, access files, or manipulate the user's PC.
* **Haxe-Controlled Filesystem:** Modders can interact with files strictly through custom, secure Haxe bridges (`modReadFile` / `modSaveFile`), ensuring player safety.
* **Bytecode Execution Optimization:** By utilizing native Python pre-compilation (`.pyc` structures), runtime calls like `opponentNoteHit` skip text-parsing overhead completely. The virtual machine executes pure binary bytecode, resulting in rock-solid FPS and zero micro-stutters during heavy note spam.

## 🐍 Quick Python Syntax Guide (For Lua/Haxe Devs)

--- About the Python syntax ---

The end of indentation is the end of current block (like:

if curBeat % 2 == 0:
    debugPrint("curBeat is even")
)

Colon: after the cycle, function("def"), class and "if" you should leave a colon(":")

Trailing semicolon: you can leave a trailing semicolon to separate the commands(like:
debugPrint("This is the first command!"); debugPrint("This is the second command")
). But don't leave a trailing semicolon on empty string


The expression operators: "==", "!=", ">", "<", ">=", "<=", "or"(like Haxe "||"), "and"(like Haxe "&&"),
"not", "in", "is"

About the "if" statement: instead of "elseif" in Lua and "else if" in Haxe Python contains "elif"(but does the same)

## 📝 Script Example (`script.py`)

Here is a quick look at how clean, readable, and powerful Python scripts look in this engine. It fully supports native object-oriented classes and standard Friday Night Funkin' event hooks with safe local state tracking:

```python
# Pure Python OOP with complete memory isolation
class CustomUiMod:
    def __init__(self):
        self.mod_name = "Python Hud Mod"
        self.miss_count = 0

    def onCreatePost(self):
        # Using pre-made Haxe-Flixel wrappers safely
        makePyText('pyStatusText', 'Python Engine Active!', 500, 200, 300)
        setTextSize('pyStatusText', 24)
        setTextColor('pyStatusText', '00FF00')
        addPyText('pyStatusText')

    def onBeatHit(self):
        # Secure variable retrieval from Haxe engine
        current_beat = int(getProperty('curBeat'))
        
        # Bumping health icons every 2 beats
        if current_beat % 2 == 0:
            setProperty('iconP1.angle', -15)
            setProperty('iconP2.angle', 15)
        else:
            setProperty('iconP1.angle', 15)
            setProperty('iconP2.angle', -15)
            
        # Triggering standard animations smoothly
        if current_beat % 4 == 0:
            playAnim('boyfriend', 'hey', True)

    def opponentNoteHit(self, note_id, note_data, note_type, is_sustain):
        # Precise, lightning-fast native health damage calculations
        current_health = getHealth() 
        damage = 0.01 if is_sustain else 0.05
        
        # Safe mathematical constraints without external process leaks
        new_health = max(0.05, current_health - damage) 
        setHealth(new_health)

# Instantiating the class triggers the sandbox system automatically
active_mod_instance = CustomUiMod()

def onCreatePost(): active_mod_instance.onCreatePost()
def onBeatHit(): active_mod_instance.onBeatHit()
def opponentNoteHit(i, d, t, s): active_mod_instance.opponentNoteHit(i, d, t, s)
```
