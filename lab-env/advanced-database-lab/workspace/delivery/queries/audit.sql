SELECT batch_id,started_at,finished_at,status,error FROM audit.batch ORDER BY started_at DESC LIMIT 10;
SELECT batch_id,step,source_count,loaded_count,rejected_count,excluded_count FROM audit.step_counts ORDER BY batch_id DESC,step LIMIT 12;
