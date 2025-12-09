# Setup For Self-Guided Learners

Use this guide if you are working on these labs on your own at home!

---

## 📋 1. Pre-Requisites

You will need:

- A personal GitHub account - [signup here for free](https://github.com/signup)
- An active Azure account -  [signup here for free](https://aka.ms/free)
- A laptop with a modern browser - we recommend Microsoft Edge
- Some familiarity with - Git, VSCode, Python & Jupyter notebooks
- Some familiarity with - Generative AI concepts and workflows

<br/>

## 🚀 2. Setup Dev Environment

First, let's get you set up with a development environment for the lab. The repository is setup with a `devcontainer.json` that provides a pre-build development environment with all tools and dependencies installed. Let's activate that in three steps!

### 2.1. Fork This Repo

1. Create a fork of this repo in your personal profile [using this link](https://github.com/microsoft/ignite25-PREL13-observe-manage-and-scale-agentic-ai-apps-with-azure-ai-foundry/fork)
1. Open a new browser tab - navigate to your new fork

### 2.2. Launch GitHub Codespaces

1. Click the blue "Code" button - select the "Codespaces" tab
1. Click "+" to launch a new codespace - it opens a new tab
1. You will see a VS Code IDE - wait till that loads completely

### 2.3. Authenticate With Azure

1. Open a terminal in that VS Code session - wait till prompt is active
1. Run this command - follow steps to complete auth with **your** subscription

    ```bash title="" linenums="0"
    az login
    ```
1. When flow is complete, return to VS Code - accept default subscription

_Your development environment is ready - and connected to Azure!_

<br/>

## ⚙️ 3. Provision Your AI Agents Resources

1. We'll jumpstart our development using the [Get Started With AI Agents](https://github.com/Azure-Samples/get-started-with-ai-agents) template
1. This provides a solution architecutre with sample code & infrastructure files
1. We created a _custom_ version of this template that you can install with infra.

_Let's get this done_

1. Open a new VS Code Terminal. Complete these steps:

    ```bash
    cd infra
    ./1-setup.sh
    ```
1. Then complete the interactive steps providing responses like this:

    1. Enter branch name: `aitour26-demos`
    1. Enter environment name: `aitour-brk443`
    1. Enter Azure region: `swedencentral`
    1. Enter Subscription ID: _your subscription id here_
    1. Do you want to select a different model? (yes/no) [no]: **no**
    1. Enter deployment capacity [50]: **50**
    1. Do you want to activate Azure AI Search? (yes/no) [no]: **yes**
    1. Use these defaults? (yes/no) [yes]: **yes**
    1. Proceed with deployment? (yes/no): **yes**

1. When complete you should see:

    1. A successful deployment message in the terminal:

    ````
      SUCCESS: Your up workflow to provision and deploy to Azure completed in 6 minutes 24 seconds.
        ✓ Infrastructure deployed successfully

        ======================================
        Setup Complete!
        ======================================
        ✓ Repository cloned
        ✓ Environment configured
        ✓ Infrastructure deployed
        ℹ️  Azure AI Search not enabled
        ======================================
    ```

    1. A `infra/ForBeginners/` folder cloned from a template repo
    1. A `infra/ForBeginners/.azd-setup` with infrastructure files
    1. A `infra/ForBeginners/.azd-setup/.azure` with infra env config

<br/>

**TROUBLESHOOTING:**

1. You may see issues related to "bicep" not being available. To fix, do the following:
    ```bash
    cd ForBeginners/.azd-setup
    azd up
    ```

    This completes azd deployment directly and ends with something like this:

    ```bash
    SUCCESS: Your up workflow to provision and deploy to Azure completed in 12 minutes 39 seconds.
    ```

1.  You may get a deployment error part way through 

    ```bash
    Deployment Error Details:
    RequestConflict: Cannot modify resource with id '/.../providers/Microsoft.CognitiveServices/accounts/aoai-t7sla5j64lcvo' because the resource entity provisioning state is not terminal
    ```

    This is typically caused by a timing issue where a previous resource task has not completed. The best way to resolve this is to back off and try again. So just wait a few minutes, then retry this - and it should complete.

    ```bash
    azd up
    ```

<br/>

## ⚙️ 4. Set up `.env` variables.


1. Run this script from root of repo - it will create `.env` with values extracted by Azure CLI.

    ```
    ./1-get-env.sh
    ``````

<br/>


## 🎓 5. Add Model Choices

The default AI Agents template will deploy one chat model. The AI Search index creation will require a second text-embedding model.

In addition, we want to be able to show _model selection_ with evaluators and graders - so we want to have a suitable set of model choices available. This script makes that happen.

1. Update the `infra/customization/add-models.json` with the list of models you want to choose from, for deployments

1. Run this script and provide the selection you actually want deployed:

    ```bash
    ./2-add-model.sh 
    ```

1. On success you should see:

    ```bash
    ✓ Additional models deployed successfully!
    ✓ Environment variable updated with deployment configuration

    ========================================
    Deployment Summary
    ========================================
    ✓ gpt-4o-mini deployed
    ✓ gpt-4.1-mini deployed
    ✓ gpt-4.1-nano deployed
    ✓ o3-mini deployed
    ✓ o4-mini deployed
    ✓ text-embedding-3-large deployed
    ========================================

    ✓ Model deployment completed successfully!
    ```

1. It will also update the `.env` file with the relevant variable and list.

<br/>


## ✅ 6. Validate your `.env` variables

1. It's easy - there's a notebook for that!
1. Open `labs/00-validate-setup.ipynb` in your Visual Studio Code editor.
1. Select Kernel - pick the default Python environment
1. "Run All" - to have validation checks run.

```bash
============================================================
📊 VALIDATION SUMMARY
============================================================
✅ Valid variables: 47
❌ Missing variables: 0

🎉 All environment variables are properly configured!
   You're ready to proceed with the lab exercises.
```


<br/>

## 📚 9. Complete Your Labs

_Your infrastructure is now ready! You can now launch the instruction guide and start working through the labs!_.

1. Open a new terminal in VS Code.
1. Type `mkdocs serve` - wait a few seconds to see the pop-up dialog
1. Confirm you want to open this in browser.
1. _You should see an instruction guide for labs in website preview_. 

**Start with the Validate Setup lab - then keep going**:

1. First, run the `0-setup/00-validate-setup.ipynb` notebook
1. Verify that all required environment variables were set!
1. Then keep going down the list in the instruction guide.


<br/>

## 🧹 10. Teardown & Cleanup

When you are all done with labs, you want to tear down the infrastructure _and_ delete the cloned template sources from your repo. Make sure you are in the `infra/` folder then run this command:

```bash title="" linenums="0"
./3-teardown.sh
```

You will see:

```bash title="" linenums="0"
Starting teardown process...
Found ForBeginners directory
Checking for AZD environments...
Found AZD environment: nitya-Ignite-PREL13
======================================
WARNING: This will delete all Azure resources
======================================
Tear down Azure infrastructure? (yes/no): St
```

Respond with "yes" - and wait till complete. This will take 15-20 minutes to unprovision the resource group and purge resources. _You can now use the `./1-setup.sh` script if you want to restart install from scratch_.

---

## 🆘 Troubleshooting

### (Optional) Refresh Env From Existing Infra

What if you had provisioned infrastructure earlier - but had deleted your Codespaces? Can you _restore_ environment variables from an existing infrastructure?

Yes. Note that the `infra/1-get-env.sh` script only needs your subscription and a resource group, and it can retrieve and update your `.env`. 

### Common issues and solutions

| Issue | Solution |
|-------|----------|
| **Script fails with "Not logged in"** | Run `az login` again and complete authentication |
| **Resource group not found** | Ensure you're using the correct Azure subscription |
| **MkDocs won't start** | Try `pip install -r requirements-dev.txt` first |
| **Notebook kernel not found** | Select the Python kernel from the top-right kernel picker |
| **Bicep deployment fails** | Navigate to `ForBeginners/.azd-setup` and run `azd up` directly |
| **Model deployment conflicts** | Wait a few minutes and retry with `azd up` |

### Additional resources

- 🐛 [Report issues on GitHub](https://github.com/microsoft/aitour26-BRK443-efficient-model-customization-with-microsoft-foundry/issues/new)
- 💬 Join our community on Discord to interact with other developers:

[![Discord](https://img.shields.io/badge/Discord-Join%20Community-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/3cmBfTFkH7)

---

**🎉 Congratulations!** Your lab environment is ready. Start exploring the power of Azure AI Foundry!