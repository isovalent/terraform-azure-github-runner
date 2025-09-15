import { AzureCliCredential, ManagedIdentityCredential, EnvironmentCredential, ChainedTokenCredential } from "@azure/identity";
import { setLogLevel } from "@azure/logger";
import { AppConfigurationClient, parseSecretReference } from "@azure/app-configuration";
import { SecretClient, parseKeyVaultSecretIdentifier } from "@azure/keyvault-secrets";
import { ServiceBusClient } from "@azure/service-bus";
import { Webhooks } from "@octokit/webhooks";

const config = {};
const _secretClients = {};

let _appConfigClient;
let _azureCredentials;
let _serviceBusClient;

const defaultRunnerLabels = new Set(["self-hosted", "linux", "windows", "macos", "x64", "arm", "arm64"]);

if (process.env.AZURE_LOG_LEVEL) {
    setLogLevel(process.env.AZURE_LOG_LEVEL);
}

export const validateRequest = async (data, context) => {
    let installationId;

    if (!data.action || !data.workflow_job || !data.installation || !data.installation.id) {
        context.warn("Lacking data, data.action, or data.workflow_job, or data.installation.id");
        return false;
    }

    try {
        context.debug("App Config Endpoint from AZURE_APP_CONFIGURATION_ENDPOINT env var", process.env.AZURE_APP_CONFIGURATION_ENDPOINT);
        installationId = await getConfigValue("github-installation-id", context);
        context.debug("Retrieved installationId from config", installationId);
    } catch (error) {
        context.error("Failure retrieving config value to try to match installation id. Exception", error);
    }

    if (installationId !== data.installation.id?.toString()) {
        context.error("Installation ID doesn't match config");
        return false;
    }

    const allRequestedRunnerLabelsMatch = await validateRequestWorkflowJobLabels(data, context);
    context.debug("Checked runner label match, with result", allRequestedRunnerLabelsMatch);

    if (!allRequestedRunnerLabelsMatch) {
        context.debug({
            workflowJobId: data.workflow_job.id,
            workflowJobLabels: data.workflow_job.labels,
        }, "Requested labels do not match labels of self-hosted runners");

        return false;
    }

    return true;
};

const validateRequestWorkflowJobLabels = async (data, context) => {
    const githubRunnerLabelsString = await getConfigValue("github-runner-labels", context);
    const githubRunnerLabels = new Set(JSON.parse(githubRunnerLabelsString));
    const { labels } = data.workflow_job;

    if (labels.length === 0) {
        context.debug("0 length labels array found");

        return false;
    }

    return labels.every((label) => defaultRunnerLabels.has(label.toLowerCase()) || githubRunnerLabels.has(label));
};

export const validateRequestSignature = async (data, signature) => {
    const webhookSecret = await getSecretValue("github-webhook-secret");
    const webhooks = new Webhooks({ secret: webhookSecret });
    return webhooks.verify(data, signature);
};

const createServiceBusClient = async (context) => new ServiceBusClient(
    (await getConfigValue("azure-service-bus-namespace-uri", context)),
    getAzureCredentials(),
);

const getServiceBusClient = async (context) => {
    if (!_serviceBusClient) {
        _serviceBusClient = await createServiceBusClient(context);
    }

    return _serviceBusClient;
};

const getConfigValue = async (key, context) => {
    if (!config[key]) {
        context.debug("Attempting getConfigValue with key", key, context);

        const appConfigClient = getAppConfigurationClient();

        const { value } = await appConfigClient.getConfigurationSetting({
            key,
        });

        config[key] = value;
    }

    context.debug("Returning config[key]", config[key]);

    return config[key];
};

const getSecretValue = async (key) => {
    if (!config[key]) {
        const appConfigClient = getAppConfigurationClient();

        const response = await appConfigClient.getConfigurationSetting({
            key,
        });

        const secretReference = parseSecretReference(response);
        const { name: secretName, vaultUrl } = parseKeyVaultSecretIdentifier(secretReference.value.secretId);

        const secretClient = getSecretClient(vaultUrl);
        const { value } = await secretClient.getSecret(secretName);

        config[key] = value;
    }

    return config[key];
};

const createSecretClient = (keyVaultUrl) => new SecretClient(keyVaultUrl, getAzureCredentials());

const getSecretClient = (keyVaultUrl) => {
    if (!_secretClients[keyVaultUrl]) {
        _secretClients[keyVaultUrl] = createSecretClient(keyVaultUrl);
    }

    return _secretClients[keyVaultUrl];
};

const createAppConfigurationClient = () => new AppConfigurationClient(
    process.env.AZURE_APP_CONFIGURATION_ENDPOINT,
    getAzureCredentials(),
);

const getAppConfigurationClient = () => {
    if (!_appConfigClient) {
        _appConfigClient = createAppConfigurationClient();
    }

    return _appConfigClient;
};

const getAzureCredentials = () => {
    if (!_azureCredentials) {
        const azureCliCredential = new AzureCliCredential();
        const environmentCredential = new EnvironmentCredential();
        const managedIdentityCredential = new ManagedIdentityCredential();

        _azureCredentials = new ChainedTokenCredential(
            azureCliCredential,
            environmentCredential,
            managedIdentityCredential,
        );
    }

    return _azureCredentials;
};

export const getWebHookEventsQueueSender = async (context) => {
    const serviceBusClient = await getServiceBusClient(context);
    const queueName = await getConfigValue("azure-github-webhook-events-queue", context);

    return serviceBusClient.createSender(queueName);
};
