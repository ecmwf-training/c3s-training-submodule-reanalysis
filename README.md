# ECMWF JupyterBook sub-module template

This repository is a GitHub **template** for creating and maintaining a submodule that
can be used in ECMWF Jupyter Books for learning and documentation resources.

*Please replace the above text with a description of the sub-module*

## For contributors

It is expected that external contributions are provided as pull requests
from forked repositories, as documented more thoroughly in the
[codex guidelines](https://github.com/ecmwf/codex/blob/main/Guidelines/External-Contributions.md).

### Forking this repository

When creating a fork of this repository there are several additional steps
you should take to ensure that things work as expected.
1. **Activate the github actions**
    - Navigate to the "Actions" tab at the top of the github webpage and click the button to enable actions.
2. **Set the github pages to build from github Actions**
    - Navigate to the "Settings", then to "Pages" in the left hand panel. In the "Build and deployment" section, use the dropdown and select "GitHubActions"
3. **Add a valid CDS API key to the secrets** (*Optional, required if downloading data from the CDS*)
    - Navigate to the "Settings", then to "Secrets and variables" -> "Actions" in the left hand panel. Click the "New repository secret" button and add a new secret with the Name: `CDSAPI_KEY`. The value of the Secret should be set to your CDS API key which you can find on [your profile page in the CDS](https://cds.climate.copernicus.eu/profile).

### Adding notebooks and markdown content

If creating a notebook please use the [Template notebook](./template-notebook) to ensure you
are following the expected guidelines.
Markdown content should follow a similar structure as this README.md file.
To make the added content appear in the Jupyter Book rendered pages, you must add the content to the
table of contents (`toc`) in the `myst.yml` file, e.g.:
```yml
  toc:
    ...
    - my-new-notebook.ipynb
    - my-new-markdown.md
```
Feel free to remove any of the template/placeholder content that is currently listed.

### Branch architecture

This template has been designed to be used as a sub-module for a parent repository.
Therefore the default branch for this repository is **develop**, and this branch is used to
deploy the review/development version of the JupyterBook.
The **main** branch is reserved for published content and will be maintained by ECMWF.

The repository includes github-actions which will automatically build a develop version of
the Jupyter Book that can be used for review purposes.

### GitHub Actions

:::{note}
This template is designed to be used as a sub-module for a parent repository.
The JupyterBook build here is intended for review and testing purposes, and hence
the actions are associated to the develop branch.
:::

There are two github actions in place for this repository:

#### Jupyter Book Deploy

The **`Jupyter Book Deploy`** action builds the Jupyter Book using the same procedure as
local build described below then, if action is running on the `develop` branch, the build
is deployed to github pages.
The action is activated or when a change is made to the `develop` branch
(e.g. after merging a pull request) or when a pull request to the `develop` branch is opened.
It can also be triggered manually from the Actions tab in the github page.

#### Notebook QA

The **`Notebook QA`** action runs a series of Quality Assessment checks on the notebooks in
the repository. For example the code must meet acceptable coding standards and the notebooks
must run to completion. This check is considered as part of the review process when accepting
new notebooks to the repository.

### Build and check the Jupyter Book locally

The following instructions assume you have cloned the repository and are in the top-level directory of the repository.

#### Create environment and install dependancies for building the Jupyter Book

Create a clean environment using the package manager of your preference,
and install the CI dependencies.
Below are examples for working with `conda` and `uv` package managers.

**conda**:
```sh
# Create a conda environment, this only needs to be executed the once.
conda create -y -n jupyter-build -c conda-forge python=3.12

# To activate the conda environment.
conda activate jupyter-build

# Install the depdencies used by jupyterbook build to run the notebooks (specified in requirements.txt)
make conda-env-update
```

**uv**:
```sh
# Create and activate a uv virtual environment.
uv venv .venv --python 3.12

# To activate the uv environment
source .venv/bin/activate 

# Install the depdencies used by jupyterbook build and to run the notebooks (specified in requirements.txt)
make uv-env-update
```

#### Build and render the book locally

```sh
make jupyter-book
```

You will then be provided with a `localhost` link to view your notebook.

:::{note}
If you have multiple instances of Jupyter Book running on your computer,
the actions may fail as they are not able find an available port to host the
Jupyter Book.
:::

#### Run the Notebook QA checks

To run the quality assurance checks, run the following command:

```
make qa
```

:::{note}
The `make qa` command will clone a git repository to a hidden directory (.qa-tools)
and install the dependancies required to execute all the quality assurance checks.
It is recommended that you do this in a virtual environment.
:::

### Syncing core components from the template

This repository was created from [`jupyterbook-submodule-template`](https://github.com/ecmwf-training/jupyterbook-submodule-template).
Updates to the template's core components (`.github/`, `Makefile`, `setup.cfg`, `README.md`)
can be pulled into your repository at any time:

```sh
make template-update
```

This adds the template as a git remote named `template`, fetches the `main` branch, and checks
out the core files into your working tree. **No commit is made automatically** — all changes
are left unstaged so you can review them before deciding what to keep.

:::{important}
Local changes to the synced files will **not** be preserved automatically.
Before running `make template-update`, note any customisations you have made to
`.github/`, `Makefile`, or `setup.cfg`. After the sync, use `git diff HEAD` to
review what changed and manually reapply any local modifications before committing.

The file `.github/notebook-qa.yml` is included in the `.github/` directory and will
also be overwritten. If you have customised pynblint rules or disabled checks in that
file, back up your changes before syncing.
:::

