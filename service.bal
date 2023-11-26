import ballerina/http;

service / on new http:Listener(9090) {

    resource function get greeting(string name) returns string|error {

        if name is "" {
            return error("name should not be empty!");
        }

        return "Hello, " + name;
    }

    resource isolated function get healthCheck() returns json|error? {

        // Check API 01
        APIStatus api01Status = api01();

        // Check API 02
        APIStatus api02Status = api02();

        Status overallStatus;
        if (api01Status.status == PASS && api02Status.status == PASS) {
            overallStatus = PASS;
        } else {
            overallStatus = FAIL;
        }

        json healthCheckResponse = {
            "status": overallStatus,
            "version": "1.0",
            "description": "health of choro service",
            "checks": [
                api01Status.toJson(),
                api02Status.toJson()
            ]
        };

        return healthCheckResponse;
    }
}

enum Status {
    PASS = "pass", // HTTP response code in the 2xx-3xx range MUST be used.
    FAIL = "fail", // HTTP response code in the 4xx-5xx range MUST be used.
    WARN = "warn" // MUST return HTTP status in the 2xx-3xx range, and additional information SHOULD be provided in the response body.
}

// Use `open record` type to allow the record to be extended when needed.
type APIStatus record {
    string name;
    Status status;
};

isolated function api01() returns APIStatus {
    APIStatus api01Status = {
        name: "API 01",
        status: PASS
    };

    // Check API 01

    return api01Status;
}

isolated function api02() returns APIStatus {
    APIStatus api02Status = {
        name: "API 02",
        status: PASS
    };

    // Check API 02

    return api02Status;
}
