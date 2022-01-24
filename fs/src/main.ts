import * as k8s from '@kubernetes/client-node';
import * as fs from 'fs';
import { SQLServerInstance } from './SQLServerInstance';

const sqlServerInstance = new SQLServerInstance();
const kc = new k8s.KubeConfig();
kc.loadFromDefault();
const coreAPI = kc.makeApiClient(k8s.CoreV1Api);
const customObjectsAPI = kc.makeApiClient(k8s.CustomObjectsApi);

async function reconcile(instanceName: string, namespace: string, firstPort: number, lastPort: number)
{
    let objs: { [key: string]: any } = {};

    function find(obj: any)
    {
        let ownerUID = (obj.kind == 'SQLDB') ? obj.metadata.uid : ((obj.metadata.ownerReferences || []).find((r: any) => r.kind == 'SQLDB')?.uid || null);
        
        if (obj.ownerReferences)
        {
            console.log(obj);
        }

        if (ownerUID)
        {
            let metadata = { namespace: obj.metadata.namespace, name: obj.metadata.name };
            let key = JSON.stringify(ownerUID);
            return objs[key] = objs[key] || { db: null, service: null, metadata };
        }
        return null;
    }

    for (let db of ((await customObjectsAPI.listClusterCustomObject('managedsql.api.k8s.dma.net.nz', 'v1', 'sqldbs')).body as any).items)
    {
        if (db.spec.instance == instanceName)
        {
            let obj = find(db);
            
            if (obj)
            {
                obj.db = db;
            }
        }
    }

    for (let service of (await coreAPI.listServiceForAllNamespaces()).body.items)
    {
        let obj = find(service);

        if (obj)
        {
            obj.service = service;
        }
    }

    for (let obj of Object.values(objs))
    {
        let port = 0;

        if (obj.db)
        {
            let result = await sqlServerInstance.runSQL(`
                EXEC master.dbo.CreateDB @DbName = @DbName, @FirstPort = @FirstPort, @LastPort = @LastPort
            `, { DbName: `${obj.metadata.namespace}_${obj.metadata.name}`, FirstPort: firstPort, LastPort: lastPort });

            if (result)
            {
                port = result[0][0].value;
            }
        }

        if (obj.db && obj.service)
        {

        }
        else if (!obj.db && obj.service)
        {
            await coreAPI.deleteNamespacedService(obj.metadata.name, obj.metadata.namespace);
        }
        else if (obj.db && !obj.service && port)
        {
            await coreAPI.createNamespacedService(obj.metadata.namespace, {
                metadata: {
                    name: obj.metadata.name,
                    ownerReferences: [
                        {
                            apiVersion: 'managedsql.api.k8s.dma.net.nz/v1',
                            kind: 'SQLDB',
                            name: obj.metadata.name,
                            uid: obj.db.metadata.uid
                        }
                    ]
                },
                spec: {
                    type: 'ExternalName',
                    externalName: `sqlserver-${instanceName}-${port}.${namespace}.svc.cluster.local`,
                    ports: [
                        {
                            port: 1433
                        }
                    ]
                }
            });
        }

        port++;
    }
}

async function main()
{
    let instanceName = process.env.INSTANCE_NAME as string;
    let namespace = process.env.NAMESPACE as string;
    let password = process.env.SA_PASSWORD as string;
    let firstPort = parseInt(process.env.FIRST_PORT as string);
    let lastPort = parseInt(process.env.LAST_PORT as string);

    while (true)
    {
        try
        {
            await sqlServerInstance.connect(instanceName, password);
            break;
        }
        catch (e)
        {
            console.error(e);
        }
    }

    for (let batch of (await fs.promises.readFile('./procedures.sql', 'utf8')).split('\nGO'))
    {
        await sqlServerInstance.runSQL(batch);
    }
    
    const exit = (reason: string) => {
        process.exit(0);
    };
    
    process.on('SIGTERM', () => exit('SIGTERM'))
           .on('SIGINT', () => exit('SIGINT'));

    while (true)
    {
        try
        {
            await reconcile(instanceName, namespace, firstPort, lastPort);
        }
        catch (e)
        {
            console.error(e);
        }
        await new Promise((resolve, reject) => setTimeout(resolve, 1000));
    }
}

main();