import { validateRequest, validateRequestSignature, getWebHookEventsQueueSender } from "./util.js";

export const eventHandler = async function (context, req) {
    context.log.verbose("JavaScript HTTP trigger function processed a request.", req.body);

    if (await validateRequestSignature(context, req).catch((e) => {
        context.log.error("Error validating request signature", e);
        context.res = {
            status: 500,
            body: "Unable to validate request signature",
        };
        return;
    })) {
        context.res = {
            status: 200,
            body: "Valid webhook message received. Queued for processing",
        };

        const isValid = await validateRequest(context, req);
        if (isValid) {
            const sender = await getWebHookEventsQueueSender(context);

            await sender.sendMessages({
                body: req.body,
            });
            context.log.verbose("Placed message on queue", sender);
        }

    } else {
        context.res = {
            status: 403,
            body: "Invalid request signature",
        };
        return;
    }
};
