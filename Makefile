EXTENSION = pgpyml_try
DATA = pgpyml_try--0.3.1--0.3.2.sql
 
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
