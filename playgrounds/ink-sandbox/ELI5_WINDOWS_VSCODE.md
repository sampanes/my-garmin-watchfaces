# Ink Sandbox: ELI5 Windows + VS Code Guide

This file is the "I forgot everything" guide.

If your brain feels wiped, follow this exactly.

## What this sandbox is

This is a tiny art playground that runs in your web browser.

It is for:

- trying brush-stroke ideas
- trying mist / mountain / ink ideas
- changing code
- saving the file
- seeing the browser update fast

This is much faster than doing a full Garmin build every time.

## Where it is

Folder:

- `playgrounds/ink-sandbox`

Important files:

- `index.html`
- `main.js`
- `style.css`
- `package.json`

## What you need installed

You need:

- VS Code
- Node.js

If you already use VS Code and can run `npm` commands, you are probably fine.

## The easiest workflow

We want this:

1. open folder in VS Code
2. run a command once to install the sandbox tools
3. run a command to start the local website
4. open the website in your browser
5. edit `main.js`
6. save
7. browser updates

## Step 1: Open the repo in VS Code

Open VS Code.

Then:

1. Click `File`
2. Click `Open Folder...`
3. Open this folder:

```text
C:\Users\John\Documents\Personal_Projects\my-garmin-watchfaces
```

## Step 2: Open a terminal in VS Code

In VS Code:

1. Click `Terminal`
2. Click `New Terminal`

A terminal should open at the bottom.

## Step 3: Go into the sandbox folder

Type this in the terminal:

```powershell
cd playgrounds\ink-sandbox
```

Then press `Enter`.

## Step 4: Install the sandbox tool

Type this:

```powershell
npm install
```

Then press `Enter`.

What this does:

- downloads the local dev tool (`vite`)
- creates a `node_modules` folder

You only need to do this again if that folder disappears or the sandbox dependencies change.

## Step 5: Start the local website

Type this:

```powershell
npm run dev
```

Then press `Enter`.

After a moment, you should see something like:

```text
Local: http://localhost:5173/
```

The number might be different, but usually it will be `5173`.

## Step 6: Open it in your browser

Hold `Ctrl` and click the local URL in the VS Code terminal.

Usually:

```text
http://localhost:5173/
```

That should open the sandbox in your browser.

## Step 7: Edit the art code

In VS Code, open:

- `playgrounds/ink-sandbox/main.js`

That file controls most of the drawing.

Examples of what to change:

- ridge shape
- brush stamp shape
- cluster counts
- spacing
- mist
- darkness

## Step 8: Save and watch it update

After changing `main.js`:

1. Press `Ctrl+S`

Then:

- the browser should refresh or update on its own
- you should see the new drawing almost immediately

This is the main reason this sandbox exists.

## Very important: how to stop it

In the VS Code terminal where `npm run dev` is running:

1. click in that terminal
2. press `Ctrl+C`

That stops the local website server.

## Next time you come back

Usually you do **not** need `npm install` again.

Usually you only need:

```powershell
cd playgrounds\ink-sandbox
npm run dev
```

Then open the local URL again.

## If `npm` says it is not recognized

That usually means Node.js is not installed or not available in the terminal.

If that happens:

1. install Node.js
2. close and reopen VS Code
3. try again

## If the browser does not update

Try this:

1. make sure `npm run dev` is still running
2. make sure you saved the file with `Ctrl+S`
3. refresh the browser manually with `F5`

## If you forget everything, use this tiny version

Open VS Code terminal and run:

```powershell
cd C:\Users\John\Documents\Personal_Projects\my-garmin-watchfaces\playgrounds\ink-sandbox
npm install
npm run dev
```

Then open the local URL it prints.

After that:

- edit `main.js`
- save
- look at browser

## What file does what

`main.js`

- the art logic
- mountains
- stamps
- mist
- ridge

`style.css`

- how the page looks
- layout
- colors around the canvas

`index.html`

- the page structure
- canvas
- reroll button

`package.json`

- tells npm how to run the local dev server

## If you want the shortest possible memory aid

Use this:

```text
Open repo in VS Code
Open terminal
cd playgrounds\ink-sandbox
npm run dev
Open localhost link
Edit main.js
Save
Look at browser
```
