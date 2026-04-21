# UnrealDiversion
Unreal Plugin for Diversion SCM



## Generating yaml API Code

### Getting template files for a specific generator:
`openapi-generator-cli author template -g <generator_name> -o ./<output_path>`

### Getting the debug data for a specific YAML file:
Add at the end of the generation line - 

`openapi-generator-cli generate -i .\Source\AgentAPI\agentapi.yaml -g cpp-restsdk -c .\agent_config.json -t .\openapi_templates\ -o .\Source\AgentAPI\ --global-property debugModels=true,debugOperations=true > debug.json 2>&1`

### Build the AgentAPI:

`openapi-generator-cli generate -i .\Source\AgentAPI\agentapi.yaml -g cpp-restsdk -c .\agent_config.json -t .\openapi_templates\ -o .\Source\AgentAPI\ && python post_process.py --input-dir .\Source\AgentAPI\ --config .\agent_post_process_config.json`

openapi-generator-cli generate -i .\Source\AgentAPI\agentapi.yaml -g cpp-restsdk -c .\agent_config.json --dry-run -t .\openapi_templates\ -o .\Source\AgentAPI\ --global-property debugModels=true,debugOperations=true > debug.json 2>&1

### Build the CoreAPI:

`openapi-generator-cli generate -i .\Source\CoreAPI\coreapi.yml -g cpp-restsdk -c .\core_config.json -t .\openapi_templates\ -o .\Source\CoreAPI\ && python post_process.py --input-dir .\Source\CoreAPI\ --config .\core_post_process_config.json`

openapi-generator-cli generate -i .\Source\CoreAPI\coreapi.yml -g cpp-restsdk -c .\core_config.json --dry-run -t .\openapi_templates\ -o .\Source\CoreAPI\ --global-property debugModels=true,debugOperations=true > debug.json 2>&1

<!-- Build the CoreAPI:

`java -jar .\openapi_templates\openapi-generator-cli-7.7.0-SNAPSHOT.jar generate -i .\Source\CoreAPI\coreapi.yml -g cpp-ue4 -c .\Source\CoreAPI\config.yaml  -t .\openapi_templates\ -o .\Source\CoreAPI\` -->