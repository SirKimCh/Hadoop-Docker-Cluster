import java.io.IOException;
import java.util.HashSet;
import java.util.regex.Pattern;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.input.NLineInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class OnlineRetailQ2 {

    public static class RetailMapper extends Mapper<Object, Text, Text, Text> {

        private Text country = new Text();
        private Text customerId = new Text();
        private static final Pattern CSV_PATTERN = Pattern.compile(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            String[] fields = CSV_PATTERN.split(value.toString(), -1);

            if (fields.length < 8 || fields[0].equals("Invoice")) {
                return;
            }

            String invoiceVal = fields[0].trim();
            String customerIdVal = fields[6].trim();
            String countryVal = fields[7].trim();

            if (invoiceVal.isEmpty() || invoiceVal.startsWith("C") || customerIdVal.isEmpty() || countryVal.isEmpty()) {
                return;
            }

            country.set(countryVal);
            customerId.set(customerIdVal);
            context.write(country, customerId);
        }
    }

    public static class RetailReducer extends Reducer<Text, Text, Text, IntWritable> {

        private IntWritable result = new IntWritable();

        public void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
            HashSet<String> uniqueSet = new HashSet<>();

            for (Text val : values) {
                uniqueSet.add(val.toString());
            }

            context.write(key, new IntWritable(uniqueSet.size()));
        }
    }

    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "online retail q2");
        job.setJarByClass(OnlineRetailQ2.class);
        job.setMapperClass(RetailMapper.class);
        job.setReducerClass(RetailReducer.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);

        if (args.length > 2) {
            int linesPerMap = Integer.parseInt(args[2]);
            job.setInputFormatClass(NLineInputFormat.class);
            NLineInputFormat.setNumLinesPerSplit(job, linesPerMap);
        }

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
