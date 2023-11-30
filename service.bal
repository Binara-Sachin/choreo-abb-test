import ballerina/http;
import ballerinax/redis;
import ballerina/uuid;
import ballerina/io;

configurable string REDIS_CONTAINER_HOST = ?;
configurable string REDIS_PASSWORD = ?;

redis:ConnectionConfig redisConfig = {
    host: REDIS_CONTAINER_HOST,
    password: REDIS_PASSWORD,
    options: {
        connectionPooling: true,
        isClusterConnection: false,
        ssl: true,
        startTls: true,
        verifyPeer: false,
        connectionTimeout: 500
    }
};

final redis:Client conn = check new (redisConfig);

//Health Check API - Configurations
const string HEALTH_CHECK_API_VERSION = "1.0";

//Health Check API - Application Names
const string ASGARDEO_NAME = "Asagardeo Connectivity";
const string REDIS_NAME = "Redis Service";

//Health Check API - Redis Configurations
const string REDIS_MONITORING_KEY = "healthCheckKey";

enum Status {
    PASS = "pass",
    FAIL = "fail"
}

type HealthStatus record {
    string name;
    Status status;
};

service / on new http:Listener(9090) {

    resource function get greeting(string name) returns string|error {

        if name is "" {
            return error("name should not be empty!");
        }

        return "Hello, " + name;
    }

    resource isolated function get healthCheck(http:Caller caller) returns error? {

        HealthStatus api01Status = api01HealthCheck();
        HealthStatus redisStatus = redisHealthCheck();

        Status overallStatus;
        if (api01Status.status == PASS && redisStatus.status == PASS) {
            overallStatus = PASS;
        } else {
            overallStatus = FAIL;
        }

        json healthCheckResponse = {
            "status": overallStatus,
            "version": HEALTH_CHECK_API_VERSION,
            "description": "Health Check API",
            "checks": [
                api01Status.toJson(),
                redisStatus.toJson()
            ]
        };

        http:Response quickResponse = new;
        
        if (overallStatus == PASS) {
            quickResponse.statusCode = http:STATUS_OK;
        } else {
            quickResponse.statusCode = http:STATUS_SERVICE_UNAVAILABLE;
        }
        
        quickResponse.setJsonPayload(healthCheckResponse);

        check caller->respond(quickResponse);
    }
}

isolated function api01HealthCheck() returns HealthStatus {
    HealthStatus api01Status = {
        name: "API 01",
        status: PASS
    };

    // Check API 01

    return api01Status;
}

isolated function redisHealthCheck() returns HealthStatus {

    HealthStatus healthStatus;

    string monitoringValue = uuid:createType1AsString();

    string|error stringSetresult = conn->set(REDIS_MONITORING_KEY, monitoringValue);

    if (stringSetresult is error) {
        io:println("Error while setting a value to Redis: " + stringSetresult.message());
        healthStatus = {
            name: REDIS_NAME,
            status: FAIL,
            "error": "Error while setting a value to Redis"
        };
    } else {
        string?|error stringGetresult = conn->get(REDIS_MONITORING_KEY);
        if (stringGetresult is error) {
            healthStatus = {
                name: REDIS_NAME,
                status: FAIL,
                "error": "Error while getting a value from Redis"
            };
        } else {
            if (stringGetresult != monitoringValue) {
                healthStatus = {
                    name: REDIS_NAME,
                    status: FAIL,
                    "error": "Invalid return value"
                };
            } else {
                healthStatus = {
                    name: REDIS_NAME,
                    status: PASS
                };
            }
        }
    
    }

    return healthStatus;
}