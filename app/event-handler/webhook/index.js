import { app } from '@azure/functions';
import { validateRequest, validateRequestSignature, getWebHookEventsQueueSender } from "./util.js";

app.http("webhook", {
    methods: ["POST"],
    handler: async (request, context) => {
        context.log("HTTP trigger processed a request.");

        if (request.headers.get("x-github-event") !== "workflow_job") {
            context.log("Ignoring non-workflow_job event");
            return { status: 400, body: "Bad Request. Invalid Github Event Received" };
        }

        const data = await request.json();

        const payload = JSON.stringify(data);
        context.debug("Received payload:", payload);
        if (!(await validateRequestSignature(
            payload, request.headers.get("x-hub-signature-256")
        ))) {
            context.log("Invalid signature");
            return { status: 403, body: "Unauthorized, Failed to Validate Signature" };
        }

        const isValid = await validateRequest(data, context);
        if (isValid) {
            const sender = await getWebHookEventsQueueSender(context);
            await sender.sendMessages({
                body: data,
            });
            context.debug("Dispatched message to Message Bus to handle Runner Logistics", sender);
            return { body: `Request Sent to create runner for ${payload.workflow_job?.run_url}` }
        }

        context.log("This request cannot be served by this stack");
    }
});
