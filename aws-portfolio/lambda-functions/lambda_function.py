import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('ktad-portfolio-table')

def lambda_handler(event, context):
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
    }
    
    # Obsługa CORS dla przeglądarki
    method = event.get('httpMethod') or event.get('requestContext', {}).get('http', {}).get('method')
    
    try:
        if method == 'POST':
            # Zwiększamy licznik
            response = table.update_item(
                Key={'PK': 'total_visits'},
                UpdateExpression="ADD visits :inc",
                ExpressionAttributeValues={':inc': 1},
                ReturnValues="UPDATED_NEW"
            )
            count = response['Attributes']['visits']
        else:
            # Tylko pobieramy (GET)
            response = table.get_item(Key={'PK': 'total_visits'})
            count = response.get('Item', {}).get('visits', 0)

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'count': str(count)})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }