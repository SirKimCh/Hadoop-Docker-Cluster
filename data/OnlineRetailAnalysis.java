import java.io.IOException;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.DoubleWritable;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.NullWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class OnlineRetailAnalysis {

    private static final int EXPECTED_COLUMNS = 8;

    private static class RetailRecord {
        String invoice;
        double quantity;
        double price;
        String customerId;
        String country;
    }

    private static List<String> parseCsvLine(String line) {
        List<String> fields = new ArrayList<String>();
        StringBuilder current = new StringBuilder();
        boolean inQuotes = false;

        for (int i = 0; i < line.length(); i++) {
            char c = line.charAt(i);
            if (inQuotes) {
                if (c == '"') {
                    if (i + 1 < line.length() && line.charAt(i + 1) == '"') {
                        current.append('"');
                        i++;
                    } else {
                        inQuotes = false;
                    }
                } else {
                    current.append(c);
                }
            } else if (c == '"') {
                inQuotes = true;
            } else if (c == ',') {
                fields.add(current.toString());
                current.setLength(0);
            } else {
                current.append(c);
            }
        }

        fields.add(current.toString());
        return fields;
    }

    private static RetailRecord parseRetailRecord(String line) {
        if (line == null || line.trim().isEmpty()) {
            return null;
        }

        List<String> fields = parseCsvLine(line);
        if (fields.size() != EXPECTED_COLUMNS || "Invoice".equalsIgnoreCase(fields.get(0).trim())) {
            return null;
        }

        String invoice = fields.get(0).trim();
        String country = fields.get(7).trim();
        if (invoice.isEmpty() || country.isEmpty()) {
            return null;
        }

        RetailRecord record = new RetailRecord();
        record.invoice = invoice;
        record.customerId = normalizeCustomerId(fields.get(6).trim());
        record.country = country;

        try {
            record.quantity = Double.parseDouble(fields.get(3).trim());
            record.price = Double.parseDouble(fields.get(5).trim());
        } catch (NumberFormatException ex) {
            record.quantity = 0.0;
            record.price = 0.0;
        }

        return record;
    }

    private static final long DEFAULT_SPLIT_MAX_SIZE = 16L * 1024L * 1024L;

    private static Configuration jobConfiguration(String input, int mapperCount) throws IOException {
        Configuration conf = new Configuration();
        conf.setLong("mapreduce.input.fileinputformat.split.maxsize", DEFAULT_SPLIT_MAX_SIZE);

        if (mapperCount > 0) {
            Path inputPath = new Path(input);
            FileSystem fileSystem = inputPath.getFileSystem(conf);
            long inputSize = fileSystem.isFile(inputPath)
                    ? fileSystem.getFileStatus(inputPath).getLen()
                    : fileSystem.getContentSummary(inputPath).getLength();

            if (inputSize > 0) {
                long splitSize = Math.max(1L, (inputSize + mapperCount - 1L) / mapperCount);
                conf.setInt("mapreduce.job.maps", mapperCount);
                conf.setLong("mapreduce.input.fileinputformat.split.minsize", 1L);
                conf.setLong("mapreduce.input.fileinputformat.split.maxsize", splitSize);
            }
        }

        return conf;
    }

    private static String normalizeCustomerId(String value) {
        String trimmed = value == null ? "" : value.trim();
        if (trimmed.matches("\\d+\\.0")) {
            return trimmed.substring(0, trimmed.length() - 2);
        }
        return trimmed;
    }

    public static class DistinctInvoiceMapper extends Mapper<Object, Text, Text, NullWritable> {
        private final Text countryInvoice = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            RetailRecord record = parseRetailRecord(value.toString());
            if (record == null) {
                return;
            }

            countryInvoice.set(record.country + "\t" + record.invoice);
            context.write(countryInvoice, NullWritable.get());
        }
    }

    public static class DistinctCustomerMapper extends Mapper<Object, Text, Text, NullWritable> {
        private final Text countryCustomer = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            RetailRecord record = parseRetailRecord(value.toString());
            if (record == null || record.customerId.isEmpty()) {
                return;
            }

            countryCustomer.set(record.country + "\t" + record.customerId);
            context.write(countryCustomer, NullWritable.get());
        }
    }

    public static class DistinctPairReducer extends Reducer<Text, NullWritable, Text, IntWritable> {
        private static final IntWritable ONE = new IntWritable(1);
        private final Text country = new Text();

        public void reduce(Text key, Iterable<NullWritable> values, Context context)
                throws IOException, InterruptedException {
            String[] parts = key.toString().split("\t", 2);
            if (parts.length == 2) {
                country.set(parts[0]);
                context.write(country, ONE);
            }
        }
    }

    public static class CountryCountMapper extends Mapper<Object, Text, Text, IntWritable> {
        private final Text country = new Text();
        private final IntWritable count = new IntWritable();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            String[] parts = value.toString().split("\t");
            if (parts.length < 2) {
                return;
            }

            try {
                country.set(parts[0]);
                count.set(Integer.parseInt(parts[1].trim()));
                context.write(country, count);
            } catch (NumberFormatException ex) {
                return;
            }
        }
    }

    public static class IntSumReducer extends Reducer<Text, IntWritable, Text, IntWritable> {
        private final IntWritable result = new IntWritable();

        public void reduce(Text key, Iterable<IntWritable> values, Context context)
                throws IOException, InterruptedException {
            int sum = 0;
            for (IntWritable value : values) {
                sum += value.get();
            }
            result.set(sum);
            context.write(key, result);
        }
    }

    public static class CustomerPurchaseMapper extends Mapper<Object, Text, Text, DoubleWritable> {
        private final Text countryCustomer = new Text();
        private final DoubleWritable amount = new DoubleWritable();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            RetailRecord record = parseRetailRecord(value.toString());
            if (record == null || record.customerId.isEmpty()) {
                return;
            }

            countryCustomer.set(record.country + "\t" + record.customerId);
            amount.set(record.quantity * record.price);
            context.write(countryCustomer, amount);
        }
    }

    public static class TopCustomerOneJobMapper extends Mapper<Object, Text, Text, Text> {
        private final Text country = new Text();
        private final Text customerAmount = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            RetailRecord record = parseRetailRecord(value.toString());
            if (record == null || record.customerId.isEmpty()) {
                return;
            }

            country.set(record.country);
            customerAmount.set(record.customerId + "\t" + (record.quantity * record.price));
            context.write(country, customerAmount);
        }
    }

    public static class TopCustomerOneJobReducer extends Reducer<Text, Text, Text, Text> {
        private static final DecimalFormat MONEY_FORMAT =
                new DecimalFormat("0.00", DecimalFormatSymbols.getInstance(Locale.US));
        private final Text result = new Text();

        public void reduce(Text key, Iterable<Text> values, Context context)
                throws IOException, InterruptedException {
            java.util.Map<String, Double> totals = new java.util.HashMap<String, Double>();

            for (Text value : values) {
                String[] parts = value.toString().split("\t", 2);
                if (parts.length != 2) {
                    continue;
                }

                double amount;
                try {
                    amount = Double.parseDouble(parts[1]);
                } catch (NumberFormatException ex) {
                    continue;
                }

                String customerId = parts[0];
                Double current = totals.get(customerId);
                totals.put(customerId, (current == null ? 0.0 : current) + amount);
            }

            double maxTotal = Double.NEGATIVE_INFINITY;
            List<String> topCustomers = new ArrayList<String>();
            for (java.util.Map.Entry<String, Double> entry : totals.entrySet()) {
                double total = entry.getValue();
                if (total > maxTotal) {
                    maxTotal = total;
                    topCustomers.clear();
                    topCustomers.add(entry.getKey());
                } else if (total == maxTotal) {
                    topCustomers.add(entry.getKey());
                }
            }

            for (String customerId : topCustomers) {
                result.set("customer_id=" + customerId + "\ttotal=" + MONEY_FORMAT.format(maxTotal));
                context.write(key, result);
            }
        }
    }

    public static class CustomerPurchaseReducer extends Reducer<Text, DoubleWritable, Text, Text> {
        private final Text country = new Text();
        private final Text customerTotal = new Text();

        public void reduce(Text key, Iterable<DoubleWritable> values, Context context)
                throws IOException, InterruptedException {
            String[] parts = key.toString().split("\t", 2);
            if (parts.length != 2) {
                return;
            }

            double total = 0.0;
            for (DoubleWritable value : values) {
                total += value.get();
            }

            country.set(parts[0]);
            customerTotal.set(parts[1] + "\t" + total);
            context.write(country, customerTotal);
        }
    }

    public static class DoubleSumCombiner extends Reducer<Text, DoubleWritable, Text, DoubleWritable> {
        private final DoubleWritable result = new DoubleWritable();

        public void reduce(Text key, Iterable<DoubleWritable> values, Context context)
                throws IOException, InterruptedException {
            double sum = 0.0;
            for (DoubleWritable value : values) {
                sum += value.get();
            }
            result.set(sum);
            context.write(key, result);
        }
    }

    public static class TopCustomerMapper extends Mapper<Object, Text, Text, Text> {
        private final Text country = new Text();
        private final Text customerTotal = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            String[] parts = value.toString().split("\t");
            if (parts.length < 3) {
                return;
            }

            country.set(parts[0]);
            customerTotal.set(parts[1] + "\t" + parts[2]);
            context.write(country, customerTotal);
        }
    }

    public static class TopCustomerReducer extends Reducer<Text, Text, Text, Text> {
        private static final DecimalFormat MONEY_FORMAT =
                new DecimalFormat("0.00", DecimalFormatSymbols.getInstance(Locale.US));
        private final Text result = new Text();

        public void reduce(Text key, Iterable<Text> values, Context context)
                throws IOException, InterruptedException {
            double maxTotal = Double.NEGATIVE_INFINITY;
            List<String> customers = new ArrayList<String>();

            for (Text value : values) {
                String[] parts = value.toString().split("\t", 2);
                if (parts.length != 2) {
                    continue;
                }

                double total;
                try {
                    total = Double.parseDouble(parts[1]);
                } catch (NumberFormatException ex) {
                    continue;
                }

                if (total > maxTotal) {
                    maxTotal = total;
                    customers.clear();
                    customers.add(parts[0]);
                } else if (total == maxTotal) {
                    customers.add(parts[0]);
                }
            }

            for (String customer : customers) {
                result.set("customer_id=" + customer + "\ttotal=" + MONEY_FORMAT.format(maxTotal));
                context.write(key, result);
            }
        }
    }

    private static boolean runDistinctCount(
            Class<? extends Mapper> mapperClass,
            String jobName,
            String input,
            String tempOutput,
            String finalOutput,
            int mapperCount) throws Exception {
        Job distinctJob = Job.getInstance(jobConfiguration(input, mapperCount), jobName + " distinct pairs");
        distinctJob.setJarByClass(OnlineRetailAnalysis.class);
        distinctJob.setMapperClass(mapperClass);
        distinctJob.setReducerClass(DistinctPairReducer.class);
        distinctJob.setMapOutputKeyClass(Text.class);
        distinctJob.setMapOutputValueClass(NullWritable.class);
        distinctJob.setOutputKeyClass(Text.class);
        distinctJob.setOutputValueClass(IntWritable.class);
        FileInputFormat.addInputPath(distinctJob, new Path(input));
        FileOutputFormat.setOutputPath(distinctJob, new Path(tempOutput));
        if (!distinctJob.waitForCompletion(true)) {
            return false;
        }

        Job sumJob = Job.getInstance(jobConfiguration(tempOutput, 0), jobName + " country totals");
        sumJob.setJarByClass(OnlineRetailAnalysis.class);
        sumJob.setMapperClass(CountryCountMapper.class);
        sumJob.setCombinerClass(IntSumReducer.class);
        sumJob.setReducerClass(IntSumReducer.class);
        sumJob.setMapOutputKeyClass(Text.class);
        sumJob.setMapOutputValueClass(IntWritable.class);
        sumJob.setOutputKeyClass(Text.class);
        sumJob.setOutputValueClass(IntWritable.class);
        FileInputFormat.addInputPath(sumJob, new Path(tempOutput));
        FileOutputFormat.setOutputPath(sumJob, new Path(finalOutput));
        return sumJob.waitForCompletion(true);
    }

    private static boolean runTopCustomer(String input, String tempOutput, String finalOutput, int mapperCount) throws Exception {
        Job job = Job.getInstance(jobConfiguration(input, mapperCount), "q3 top customer by country one job");
        job.setJarByClass(OnlineRetailAnalysis.class);
        job.setMapperClass(TopCustomerOneJobMapper.class);
        job.setReducerClass(TopCustomerOneJobReducer.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        FileInputFormat.addInputPath(job, new Path(input));
        FileOutputFormat.setOutputPath(job, new Path(finalOutput));
        return job.waitForCompletion(true);
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 4) {
            System.err.println("Usage:");
            System.err.println("  OnlineRetailAnalysis invoiceCount <input> <tempOutput> <output> [mapperCount]");
            System.err.println("  OnlineRetailAnalysis customerCount <input> <tempOutput> <output> [mapperCount]");
            System.err.println("  OnlineRetailAnalysis topCustomer <input> <tempOutput> <output> [mapperCount]");
            System.exit(2);
        }

        String command = args[0];
        int mapperCount = args.length >= 5 ? Integer.parseInt(args[4]) : 0;
        boolean success;
        if ("invoiceCount".equals(command)) {
            success = runDistinctCount(DistinctInvoiceMapper.class, "q1 invoice count by country",
                    args[1], args[2], args[3], mapperCount);
        } else if ("customerCount".equals(command)) {
            success = runDistinctCount(DistinctCustomerMapper.class, "q2 distinct customer count by country",
                    args[1], args[2], args[3], mapperCount);
        } else if ("topCustomer".equals(command)) {
            success = runTopCustomer(args[1], args[2], args[3], mapperCount);
        } else {
            System.err.println("Unknown command: " + command);
            System.exit(2);
            return;
        }

        System.exit(success ? 0 : 1);
    }
}
