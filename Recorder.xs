#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

/* Doesn't seem to exist before 5.14 */
#ifndef OP_CLASS
#define OP_CLASS(o) (PL_opargs[(o)->op_type] & OA_CLASS_MASK)
#endif

typedef enum {
    EVENT_SAW_FILE = 1,
    EVENT_ENTER_FILE,
    EVENT_ENTER_LINE,
    EVENT_DIE,
} Event_type;

typedef enum Event Event;

static HV *seen_file;
static PerlIO *recording;

int runops_recorder(pTHX);

void init_recorder() {
    seen_file = newHV();
    recording = PerlIO_open("runops-recorder.data", "w");
    PL_runops = runops_recorder;
}

static const char *prev_cop_file = NULL;
static line_t prev_cop_line = -1;

static uint32_t curr_file_id = 0;
static uint32_t next_file_id = 1;

void record_cop(COP *cop) {
    const char *cop_file = CopFILE(cop);
    line_t cop_line = CopLINE(cop);
    
    if (prev_cop_file != cop_file && cop_file != NULL) {
        STRLEN len = strlen(cop_file);
        if (!hv_exists(seen_file, cop_file, len)) {
            curr_file_id = next_file_id++;
            hv_store(seen_file, cop_file, len, newSViv(curr_file_id), 0);
            PerlIO_putc(recording, EVENT_SAW_FILE);
            PerlIO_write(recording, &curr_file_id, sizeof(uint32_t));
            PerlIO_write(recording, &len, sizeof(short));
            PerlIO_write(recording, cop_file, len);
            
        }
        else {
            SV** sv = hv_fetch(seen_file, cop_file, len, 0);
            if (sv != NULL) {
                curr_file_id = SvIV(*sv);
            }
        }
        
        prev_cop_file = cop_file;
        prev_cop_line = -1;
        PerlIO_putc(recording, EVENT_ENTER_FILE);
        PerlIO_write(recording, &curr_file_id, sizeof(uint32_t));        
    }    
    
    if (cop_line != prev_cop_line) {
        PerlIO_putc(recording, EVENT_ENTER_LINE);    
        PerlIO_write(recording, &cop_line, sizeof(line_t));
        prev_cop_line = cop_line;
    }
}

void record_exception() {
    PerlIO_putc(recording, EVENT_DIE);    
}

int runops_recorder(pTHX) {
    dVAR;
    register OP *op = PL_op;

    while (PL_op) {
        if (OP_CLASS(PL_op) == OA_COP) {
            record_cop(cCOPx(PL_op));
        }
        switch (PL_op->op_type) {
            case OP_DIE:
                record_exception(PL_op);
                break;
        }

        PL_op = CALL_FPTR(PL_op->op_ppaddr)(aTHX);    

        PERL_ASYNC_CHECK();
    }
    
    TAINT_NOT;
    return 0;
}

MODULE = Runops::Recorder		PACKAGE = Runops::Recorder		

BOOT:
    init_recorder();
    