"""Minimal Dart VM service client shared by the capture scripts."""
import json


class VmService:
    def __init__(self, ws):
        self.ws, self.next_id = ws, 0

    async def call(self, method, **params):
        self.next_id += 1
        request_id = str(self.next_id)
        await self.ws.send(json.dumps({'jsonrpc': '2.0', 'id': request_id, 'method': method, 'params': params}))
        while True:
            msg = json.loads(await self.ws.recv())
            if msg.get('id') == request_id:
                if 'error' in msg:
                    raise RuntimeError(f'{method}: {msg["error"]}')
                return msg['result']

    async def main_isolate(self):
        return next(i for i in (await self.call('getVM'))['isolates'] if 'main' in i['name'])['id']


def function_name(samples, index):
    f = samples['functions'][index]['function']
    owner = f.get('owner', {}).get('name')
    return f'{owner}.{f["name"]}' if owner and owner != f['name'] else f['name']
