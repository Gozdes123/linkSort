import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://vnzolmsjftcqcyrvhall.supabase.co'
const supabaseKey = 'sb_publishable_SaLhF_xj1c4SLl1S3ww-Ag_9odbsPho'

export const supabase = createClient(supabaseUrl, supabaseKey)
