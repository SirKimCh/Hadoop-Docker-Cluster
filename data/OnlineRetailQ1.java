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

public class OnlineRetailQ1 {

    public static class RetailMapper extends Mapper<Object, Text, Text, Text> {

        private Text country = new Text();
        private Text invoice = new Text();
        private static final Pattern CSV_PATTERN = Pattern.compile(",(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)");

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            String line = value.toString();
            String[] fields = CSV_PATTERN.split(line, -1);

            if (fields.length < 8 || fields[0].contains("Invoice")) {
                return;
            }

            String invoiceVal = fields[0].trim();
            String countryVal = fields[7].trim();

            if (invoiceVal.isEmpty() || countryVal.isEmpty() || invoiceVal.startsWith("C")) {
                return;
            }

            country.set(countryVal);
            invoice.set(invoiceVal);
            context.write(country, invoice);
        }
    }

    public static class RetailReducer extends Reducer<Text, Text, Text, IntWritable> {

        private IntWritable result = new IntWritable();

        public void reduce(Text key, Iterable<Text> values, Context context) throws IOException, InterruptedException {
            HashSet<String> uniqueInvoices = new HashSet<>();

            for (Text val : values) {
                uniqueInvoices.add(val.toString());
            }

            result.set(uniqueInvoices.size());
            context.write(key, result);
        }
    }

    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "online retail q1");
        job.setJarByClass(OnlineRetailQ1.class);
        job.setMapperClass(RetailMapper.class);
        job.setReducerClass(RetailReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));
        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
