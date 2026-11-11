import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createCipheriv, createDecipheriv, randomBytes } from 'crypto';

export type KeyRing= { 
    current: number; 
    keys: Record<string, string>
};

// Must equal the database column names: they are bound to each ciphertext.
export type PiiField=
    | 'us_first_name_enc'
    | 'us_last_name_enc'
    | 'us_phone_enc'
    | 'us_birth_date_enc'
    | 'us_address_enc';

const NONCE_LEN= 12;
const TAG_LEN= 16;

@Injectable()
export class CryptoService implements OnModuleInit{
    private keys= new Map<number, Buffer>();
    private current= 0;

    constructor(private readonly config: ConfigService) {}

    async onModuleInit(){
        this.useKeyRing(await this.loadKeyRing());
    }

    /** Production: key ring JSON in AWS Parameter Store. Local: ENCRYPTION_KEYS in .env. */
    private async loadKeyRing(): Promise<KeyRing>{
        const param= this.config.get<string>('ENCRYPTION_KEYS'); // [Parameter Store name]
        //TODO - add encryption key params ?
        if (param) {
            const { SSMClient, GetParameterCommand }= await import('@aws-sdk/client-ssm');
            const out = await new SSMClient({}).send(
                new GetParameterCommand(
                    { 
                        Name: param, 
                        WithDecryption: true 
                    }
                ),
            );
            return JSON.parse(out.Parameter?.Value ?? '');
        }
        return JSON.parse(this.config.getOrThrow<string>('ENCRYPTION_KEYS'));
    }

    useKeyRing(ring: KeyRing) {
        const keys= new Map<number, Buffer>();

        for (const [version, b64] of Object.entries(ring.keys)){
            const v= Number(version);
            const key= Buffer.from(b64, 'base64');

            if (!Number.isInteger(v) || v < 1 || v > 255){
                throw new Error('Key version must be 1-255');
            }
            if (key.length !== 32){
                throw new Error(`Key ${version} must be 32 bytes`);
            }

            keys.set(v, key);
        }
        if (!keys.has(ring.current)){
            throw new Error('Current key version is missing');
        }

        this.keys = keys;
        this.current = ring.current;
    }

    encrypt(plain: Uint8Array, aad: string): Uint8Array {
        const key= this.keys.get(this.current);
        if (!key){
            throw new Error('Encryption keys not loaded');
        }

        const nonce= randomBytes(NONCE_LEN);
        const cipher= createCipheriv('aes-256-gcm', key, nonce);

        cipher.setAAD(Buffer.from(aad));
        const ct= Buffer.concat([cipher.update(plain), cipher.final()]);
        const tag= cipher.getAuthTag();

        return new Uint8Array(Buffer.concat([Buffer.from([this.current]), nonce, ct, tag]));
    }

    decrypt(data: Uint8Array, aad: string): Buffer {
        const buf= Buffer.from(data);

        if (buf.length < 1 + NONCE_LEN + TAG_LEN){
            throw new Error('Invalid ciphertext');
        }
        const key= this.keys.get(buf[0]);

        if (!key){
            throw new Error('Unknown key version');
        }
        const nonce= buf.subarray(1, 1+ NONCE_LEN);
        const tag= buf.subarray(buf.length- TAG_LEN);
        const ct= buf.subarray(1+ NONCE_LEN, buf.length- TAG_LEN);
        const decipher= createDecipheriv('aes-256-gcm', key, nonce);

        decipher.setAAD(Buffer.from(aad));
        decipher.setAuthTag(tag);

        return Buffer.concat([decipher.update(ct), decipher.final()]);
    }

    // ---- personal fields (users table) ----
    encryptField(field: PiiField, value?: string | null): Uint8Array | null {
        return value == null ? null : this.encrypt(Buffer.from(value, 'utf8'), field);
    }
    decryptField(field: PiiField, data?: Uint8Array | null): string | null {
        return data == null ? null : this.decrypt(data, field).toString('utf8');
    }

    // ---- note files (.md in S3); bound to the note id ----
    encryptFile(content: Uint8Array, noteId: string): Uint8Array {
        return this.encrypt(content, `note-file:${noteId}`);
    }
    decryptFile(data: Uint8Array, noteId: string): Buffer {
        return this.decrypt(data, `note-file:${noteId}`);
    }
}