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
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class OnlineRetailQ2 {

    public static class RetailMapper extends Mapper<Object, Text, Text, Text> {

        private Text country = new Text();
        private Text customerId = new Text();
        private static final Pattern CSV_PATTERN = Pattern.compile(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            String line = value.toString();
            String[] fields = CSV_PATTERN.split(line, -1);

            if (fields.length < 8 || fields[0].contains("Invoice")) {
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
            HashSet<String> uniqueCustomers = new HashSet<>();

            for (Text val : values) {
                uniqueCustomers.add(val.toString());
            }

            result.set(uniqueCustomers.size());
            context.write(key, result);
        }
    }

    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "online retail q2");
        job.setJarByClass(OnlineRetailQ2.class);
        job.setMapperClass(RetailMapper.class);
        job.setReducerClass(RetailReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
