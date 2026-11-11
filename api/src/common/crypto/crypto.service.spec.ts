import { ConfigService } from '@nestjs/config';
import { CryptoService, KeyRing } from './crypto.service';

const key = (n: number) => Buffer.alloc(32, n).toString('base64');

const make = (ring: KeyRing) => {
  const s = new CryptoService({} as unknown as ConfigService);
  s.useKeyRing(ring);

  return s;
};

const ring1: KeyRing = {
  current: 1,
  keys: { '1': key(1) },
};

describe('CryptoService', () => {
  it('round-trips a field and keeps null', () => {
    const s = make(ring1);
    const enc = s.encryptField('us_first_name_enc', 'Pat')!;
    expect(s.decryptField('us_first_name_enc', enc)).toBe('Pat');
    expect(s.encryptField('us_phone_enc', null)).toBeNull();
  });
  it('puts the key version first and uses a new nonce each time', () => {
    const s = make(ring1);
    const a = s.encrypt(Buffer.from('x'), 'f');
    const b = s.encrypt(Buffer.from('x'), 'f');
    expect(a[0]).toBe(1);
    expect(Buffer.from(a).equals(Buffer.from(b))).toBe(false);
  });
  it('rejects a different field name or a tampered byte', () => {
    const s = make(ring1);
    const enc = s.encryptField('us_first_name_enc', 'pat')!;
    expect(() => s.decryptField('us_last_name_enc', enc)).toThrow();

    const bad = new Uint8Array(enc);
    bad[bad.length - 20] ^= 1; // flip a bit in enc
    expect(() => s.decryptField('us_first_name_enc', bad)).toThrow();
  });
  it('still decrypts old data after rotation and writes the new version', () => {
    const old = make(ring1).encryptField('us_address_enc', 'Beirut')!;
    const s2 = make({
      current: 2,
      keys: {
        '1': key(1),
        '2': key(2),
      },
    });

    expect(s2.decryptField('us_address_enc', old)).toBe('Beirut');
    expect(s2.encrypt(Buffer.from('x'), 'f')[0]).toBe(2);
  });
  it('fails for an unknown key version', () => {
    const enc = make({
      current: 2,
      keys: { '2': key(2) },
    }).encrypt(Buffer.from('x'), 'f');

    expect(() => make(ring1).decrypt(enc, 'f')).toThrow();
  });
  it('encrypts a 2 MB note file bound to its note id', () => {
    const s = make(ring1);
    const file = Buffer.alloc(2 * 1024 * 1024 - 1, 'a');
    const enc = s.encryptFile(file, 'note-1');

    expect(s.decryptFile(enc, 'note-1').equals(file)).toBe(true);
    expect(() => s.decryptFile(enc, 'note-2')).toThrow();
  });
});
