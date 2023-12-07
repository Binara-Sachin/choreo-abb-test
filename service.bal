import ballerina/http;
import ballerinax/redis;
import ballerina/uuid;
import ballerina/io;
import ballerina/time;

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

listener http:Listener securedEP = new (9090
    // ,
    // secureSocket = {
    //     key: {
    //         certFile: "/home/binara/WSO2/Repositories/Binara-Sachin/choreo-test/resource/security/private.key",
    //         keyFile: "/home/binara/WSO2/Repositories/Binara-Sachin/choreo-test/resource/security/public.cert"
    //     }
    // }
);

service / on securedEP {

    resource function get greeting(string name) returns string|error {
        log("Greeting API Start", "greeting");
        log("Received name: " + name, "greeting");
        if name is "" {
            return error("name should not be empty!");
        }

        log("Greeting API End", "greeting");
        return "Hello, " + name;
    }

    resource function get healthCheck(http:Caller caller) returns error? {

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

function api01HealthCheck() returns HealthStatus {
    HealthStatus api01Status = {
        name: "API 01",
        status: PASS
    };

    // Check API 01

    return api01Status;
}

function redisHealthCheck() returns HealthStatus {

    log("Redis Health Check Start", "redisHealthCheck");

    HealthStatus healthStatus;
    string monitoringValue = uuid:createType1AsString();

    log("Monitoring Value: " + monitoringValue, "redisHealthCheck");

    // string REDIS_CONTAINER_HOST = "localhost:6379";
    // string REDIS_PASSWORD = "redispw";

    redis:ConnectionConfig redisConfig = {
        host: "redis-12921.c267.us-east-1-4.ec2.cloud.redislabs.com:12921",
        password: "rqv1ImoLpSnhYFmOqklRucSs3VMqxllg",
        options: {
            connectionPooling: true,
            isClusterConnection: false,
            ssl: false,
            startTls: false,
            verifyPeer: false,
            connectionTimeout: 5000
        }
    };

    final redis:Client|error conn = new (redisConfig);

    if (conn is error) {
        log("Error while connecting to Redis: " + conn.message(), "redisHealthCheck");
        healthStatus = {
            name: REDIS_NAME,
            status: FAIL,
            "error": "Error while connecting to Redis"
        };
        return healthStatus;
    }

    string|error stringSetresult = conn->set(REDIS_MONITORING_KEY, monitoringValue);

    if (stringSetresult is error) {
        log("Error while setting a value to Redis: " + stringSetresult.message(), "redisHealthCheck");
        healthStatus = {
            name: REDIS_NAME,
            status: FAIL,
            "error": "Error while setting a value to Redis"
        };
    } else {
        string?|error stringGetresult = conn->get(REDIS_MONITORING_KEY);
        if (stringGetresult is error) {
            log("Error while getting a value from Redis: " + stringGetresult.message(), "redisHealthCheck");
            healthStatus = {
                name: REDIS_NAME,
                status: FAIL,
                "error": "Error while getting a value from Redis"
            };
        } else {
            if (stringGetresult != monitoringValue) {
                log("Invalid return value: " + stringGetresult.toString(), "redisHealthCheck");
                healthStatus = {
                    name: REDIS_NAME,
                    status: FAIL,
                    "error": "Invalid return value"
                };
            } else {
                log("Redis Health Check End", "redisHealthCheck");
                healthStatus = {
                    name: REDIS_NAME,
                    status: PASS
                };
            }
        }
    
    }

    return healthStatus;
}

function log(string message, string functionName) {
    time:Utc utc1 = time:utcNow();
    string utcString = time:utcToString(utc1);
    io:println("[" + utcString + "] " + "[" + functionName + "] " + message);
}