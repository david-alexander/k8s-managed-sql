const tds: any = require('tedious');

export class SQLServerInstance
{
    private connection: any = null;

    public async runSQL(sql: string, params: { [key: string]: any } = {})
    {
        try
        {
            return await new Promise<any>((resolve, reject) => {
                let result: any[] = [];
                let request = new tds.Request(sql, (err: any, rowCount: any) => {
                    if (err)
                    {
                        reject(err);
                    }
                    else
                    {
                        resolve(result);
                    }
                });

                for (let key in params)
                {
                    let value = params[key];

                    if (typeof(value) == 'number')
                    {
                        request.addParameter(key, tds.TYPES.Int, value);
                    }
                    else if (typeof(value) == 'string')
                    {
                        request.addParameter(key, tds.TYPES.VarChar, value);
                    }
                    else if (typeof(value) == 'boolean')
                    {
                        request.addParameter(key, tds.TYPES.Bit, value);
                    }
                    else
                    {
                        throw 'Unsupported parameter type.'
                    }
                }

                request.on('row', (row: any) => {
                    result.push(row);
                });
        
                this.connection.execSql(request);
            });
        }
        catch (e)
        {
            console.error(e);
        }
    } 
    
    public async connect(instanceName: string, password: string)
    {
        this.connection = await new Promise((resolve, reject) => {
            let connection = new tds.Connection({
                server: `sqlserver-${instanceName}`,
                authentication: {
                    type: 'default',
                    options: {
                        userName: 'sa',
                        password: password
                    }
                },
                options: {
                    trustServerCertificate: true,
                    validateBulkLoadParameters: false,
                    requestTimeout: 0
                }
            });
    
            connection.connect((err: any) => {
                if (err)
                {
                    reject(err);
                }
                else
                {
                    resolve(connection);
                }
            });
        });
    }
}