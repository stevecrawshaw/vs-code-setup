# vs-code-setup
Setup for VS code projects like Arjan Codes

This is for a VS Code project template that includes a virtual environment and some recommended extensions. The template is for Python projects with a focus on data analysis, but can be adapted for other languages.

The .gitignore file is set up to ignore the virtual environment and other common files that should not be committed to the repository. It also includes common R files and folders which should not be pushed to publis repos.

## How to use:

Click "Use this template" - Create a new repository.

Give the repo a name and description.
Create the repository.

## Clone the repository
Here you are essentially copying the repo you created from the template onto your local machine, and referencing it as a git repo that is linked to the gitHUB repo.

It's best to avoid putting this on your OneDrive as aI have found that sometimes VS Code can't properly access the .venv, possibly due to OneDrive's syncing, or long path names..

copy the URL of the repo from the Code button, then go your top level folder in the terminal e.g. /projects
and type 

`git clone https://github.com/your-github-name/your-repo-name.git`

## Install packages with uv

Then in either the codespace or local machine, recreate the default .venv with uv sync.
Add new packages with uv add <package>.

Don't forget that **if you are running tools from the command line which are installed in the .venv** you need to activate the virtual environment first, e.g. on Windows:
```
.\.venv\Scripts\activate
```
on Linux or Mac:
```
source .venv/bin/activate
```
## Extensions
Some recommended extensions are included in .vscode/extensions.json.

Open the command palette (Ctrl+Shift+P) and type "Extensions: Install Extensions". Click the Funnel in the search extension bar and select "Recommended". This will show the extensions listed in .vscode/extensions.json. Click "Install All" to install them.
