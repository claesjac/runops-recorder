#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

/* Doesn't seem to exist before 5.14 */
#ifndef OP_CLASS
#define OP_CLASS(o) (PL_opargs[(o)->op_type] & OA_CLASS_MASK)
#endif

typedef enum {
    EVENT_KEYFRAME = 0,
    EVENT_SAW_FILE,
    EVENT_ENTER_FILE,
    EVENT_ENTER_LINE,
    EVENT_DIE,
} Event_type;

typedef enum Event Event;

/* Where the recording go */
static PerlIO* data_io;

/* Where the source files go */
static HV* seen_file;
static PerlIO* files_io;

static const char* base_dir;
static size_t base_dir_len;

static const char *prev_cop_file = NULL;
static line_t prev_cop_line = -1;

static uint32_t curr_file_id = 0;
static uint32_t next_file_id = 1;

static bool is_initial_recorder = TRUE;

/*
 This is so our tailing viewer knows where to start. It's inserted 
 here and there
*/
const char* KEYFRAME_DATA = "\0\0\0\0\0";

int runops_recorder(pTHX);
static const char *create_path(const char *);
static void open_recording_files();
static void record_COP(COP *);

static uint16_t keyframe_counter;
static inline void check_and_insert_keyframe() {
    if (keyframe_counter & 0x400) {
        PerlIO_write(data_io, KEYFRAME_DATA, 5);
        keyframe_counter = 0;
    }
}

static const char* create_path(const char *filename) {
    char *path;
    size_t filename_len = strlen(filename);

    Newxz(path, base_dir_len + filename_len + 2, char);
    Copy(base_dir, path, base_dir_len, char);
    Copy(filename, path + base_dir_len + 1, filename_len, char);
    path[base_dir_len] = '/';

    return (const char *) path;
}

void open_recording_files() {
    pid_t pid = getpid();
    
    const char *fn = create_path(is_initial_recorder == TRUE ? "main.data" : Perl_form("%d.data", pid));
    data_io = PerlIO_open(fn, "w");
    Safefree(fn);

    fn = create_path(is_initial_recorder == TRUE ? "main.files" : Perl_form("%d.files", pid));
    files_io = PerlIO_open(fn, "w");
    Safefree(fn);
}

static void record_switch_file(const char *cop_file) {
    STRLEN len = strlen(cop_file);

    if (!hv_exists(seen_file, cop_file, len)) {
        curr_file_id = next_file_id++;
        hv_store(seen_file, cop_file, len, newSViv(curr_file_id), 0);
        PerlIO_write(files_io, &curr_file_id, sizeof(uint32_t));
        PerlIO_write(files_io, &len, sizeof(short));
        PerlIO_write(files_io, cop_file, len);        
    }
    else {
        SV** sv = hv_fetch(seen_file, cop_file, len, 0);
        if (sv != NULL) {
            curr_file_id = SvIV(*sv);
        }
    }
    
    prev_cop_file = cop_file;
    prev_cop_line = -1;
    
    PerlIO_write(data_io, KEYFRAME_DATA, 5);
    PerlIO_putc(data_io, EVENT_ENTER_FILE);
    PerlIO_write(data_io, &curr_file_id, sizeof(uint32_t));            
}

static void record_COP(COP *cop) {
    const char *cop_file = CopFILE(cop);
    line_t cop_line = CopLINE(cop);
    
    if (prev_cop_file != cop_file && cop_file != NULL) {
        record_switch_file(cop_file);
    }    
    
    if (cop_line != prev_cop_line) {
        PerlIO_putc(data_io, EVENT_ENTER_LINE);    
        PerlIO_write(data_io, &cop_line, sizeof(uint32_t));
        prev_cop_line = cop_line;
        
        check_and_insert_keyframe();
    }
}

int runops_recorder(pTHX) {
    dVAR;
    register OP *op = PL_op;

    while (PL_op) {
        if (OP_CLASS(PL_op) == OA_COP) {
            record_COP(cCOPx(PL_op));
        }

        PL_op = CALL_FPTR(PL_op->op_ppaddr)(aTHX);    

        PERL_ASYNC_CHECK();
    }
    
    TAINT_NOT;
    return 0;
}

void init_recorder() {
    seen_file = newHV();
        
    open_recording_files();
    
    PL_runops = runops_recorder;
}

MODULE = Runops::Recorder		PACKAGE = Runops::Recorder		

void
set_target_dir(path)
    SV *path;
    PREINIT:
        STRLEN len;
    CODE:
        base_dir = SvPV(path, len);       
        base_dir_len = (size_t) len;
         
        
void
init_recorder()
    CODE:
        init_recorder();    