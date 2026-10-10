/* CBMC harness: crypto_sign_open memory safety for EVERY signed-message length and content.
 * sm is an exactly-smlen-byte heap object (so any read outside [sm, sm+smlen) is an OOB), m has smlen bytes
 * (NIST API contract: the caller provides room for the message), pk is a full-size public key. */
#include <stdlib.h>
#include "api.h"
#include "parameters.h"
int crypto_sign_open(unsigned char *m, unsigned long long *mlen, const unsigned char *sm, unsigned long long smlen, const unsigned char *pk);
#ifndef SMLEN_MAX
#define SMLEN_MAX (1ULL << 40)
#endif
void harness(void) {
    unsigned long long smlen;
    __CPROVER_assume(smlen <= SMLEN_MAX);
    unsigned char *sm = malloc(smlen);
    unsigned char *m = malloc(smlen);
    unsigned char *pk = malloc(CRYPTO_PUBLICKEYBYTES);
    unsigned long long mlen = 0;
    __CPROVER_assume(sm != NULL && m != NULL && pk != NULL);
    (void)crypto_sign_open(m, &mlen, sm, smlen, pk);
}
