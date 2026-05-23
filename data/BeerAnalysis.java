import java.io.IOException;
import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.IntWritable;
import org.apache.hadoop.io.Text;
import org.apache.hadoop.mapreduce.Job;
import org.apache.hadoop.mapreduce.Mapper;
import org.apache.hadoop.mapreduce.Reducer;
import org.apache.hadoop.mapreduce.lib.input.FileInputFormat;
import org.apache.hadoop.mapreduce.lib.output.FileOutputFormat;

public class BeerAnalysis {

    private static class Beer {
        String make;
        String type;
        String alcohol;
        double alcoholValue;
        String brewery;
    }

    private static Beer parseBeer(String line) {
        String trimmed = line == null ? "" : line.trim();
        if (trimmed.isEmpty() || trimmed.toLowerCase().startsWith("id,")) {
            return null;
        }

        String[] parts = trimmed.split(",", 5);
        if (parts.length < 5) {
            return null;
        }

        try {
            Beer beer = new Beer();
            beer.make = parts[1].trim();
            beer.type = parts[2].trim();
            beer.alcohol = normalizeAlcohol(parts[3].trim());
            beer.alcoholValue = Double.parseDouble(parts[3].trim());
            beer.brewery = parts[4].trim();
            return beer;
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private static String normalizeAlcohol(String value) {
        try {
            return new BigDecimal(value).stripTrailingZeros().toPlainString();
        } catch (NumberFormatException ex) {
            return value.trim();
        }
    }

    public static class CountByAlcoholMapper extends Mapper<Object, Text, Text, IntWritable> {
        private static final IntWritable ONE = new IntWritable(1);
        private final Text alcohol = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            Beer beer = parseBeer(value.toString());
            if (beer == null) {
                return;
            }

            alcohol.set(beer.alcohol);
            context.write(alcohol, ONE);
        }
    }

    public static class SumReducer extends Reducer<Text, IntWritable, Text, IntWritable> {
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

    public static class MostCommonMapper extends Mapper<Object, Text, Text, Text> {
        private static final Text RESULT_KEY = new Text("most_common");
        private final Text outputValue = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            String[] parts = value.toString().trim().split("\\s+");
            if (parts.length < 2) {
                return;
            }

            try {
                Integer.parseInt(parts[1]);
                outputValue.set(parts[0] + "\t" + parts[1]);
                context.write(RESULT_KEY, outputValue);
            } catch (NumberFormatException ex) {
                return;
            }
        }
    }

    public static class MostCommonReducer extends Reducer<Text, Text, Text, IntWritable> {
        private final IntWritable count = new IntWritable();

        public void reduce(Text key, Iterable<Text> values, Context context)
                throws IOException, InterruptedException {
            int maxCount = -1;
            List<String> percentages = new ArrayList<String>();

            for (Text value : values) {
                String[] parts = value.toString().split("\\t");
                if (parts.length < 2) {
                    continue;
                }

                int currentCount = Integer.parseInt(parts[1]);
                if (currentCount > maxCount) {
                    maxCount = currentCount;
                    percentages.clear();
                    percentages.add(parts[0]);
                } else if (currentCount == maxCount) {
                    percentages.add(parts[0]);
                }
            }

            count.set(maxCount);
            for (String percentage : percentages) {
                context.write(new Text(percentage), count);
            }
        }
    }

    public static class BeersByAlcoholMapper extends Mapper<Object, Text, Text, Text> {
        private String targetAlcohol;
        private final Text make = new Text();
        private final Text details = new Text();

        protected void setup(Context context) {
            targetAlcohol = normalizeAlcohol(context.getConfiguration().get("beer.target.alcohol", ""));
        }

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            Beer beer = parseBeer(value.toString());
            if (beer == null || !beer.alcohol.equals(targetAlcohol)) {
                return;
            }

            make.set(beer.make);
            details.set("alcohol=" + beer.alcohol + "\ttype=" + beer.type + "\tbrewery=" + beer.brewery);
            context.write(make, details);
        }
    }

    public static class PassThroughReducer extends Reducer<Text, Text, Text, Text> {
        public void reduce(Text key, Iterable<Text> values, Context context)
                throws IOException, InterruptedException {
            for (Text value : values) {
                context.write(key, value);
            }
        }
    }

    public static class BeerAndBreweryCountMapper extends Mapper<Object, Text, Text, Text> {
        private final Text alcohol = new Text();
        private final Text brewery = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            Beer beer = parseBeer(value.toString());
            if (beer == null) {
                return;
            }

            alcohol.set(beer.alcohol);
            brewery.set(beer.brewery);
            context.write(alcohol, brewery);
        }
    }

    public static class BeerAndBreweryCountReducer extends Reducer<Text, Text, Text, Text> {
        public void reduce(Text key, Iterable<Text> values, Context context)
                throws IOException, InterruptedException {
            int beerCount = 0;
            Set<String> breweries = new HashSet<String>();

            for (Text value : values) {
                beerCount++;
                breweries.add(value.toString());
            }

            context.write(key, new Text("beers=" + beerCount + "\tbreweries=" + breweries.size()));
        }
    }

    public static class HighestAlcoholMapper extends Mapper<Object, Text, Text, Text> {
        private static final Text RESULT_KEY = new Text("highest_alcohol");
        private final Text details = new Text();

        public void map(Object key, Text value, Context context) throws IOException, InterruptedException {
            Beer beer = parseBeer(value.toString());
            if (beer == null) {
                return;
            }

            details.set(beer.alcoholValue + "\t" + beer.make + "\t" + beer.brewery);
            context.write(RESULT_KEY, details);
        }
    }

    public static class HighestAlcoholReducer extends Reducer<Text, Text, Text, Text> {
        public void reduce(Text key, Iterable<Text> values, Context context)
                throws IOException, InterruptedException {
            double maxAlcohol = Double.NEGATIVE_INFINITY;
            List<String> beers = new ArrayList<String>();

            for (Text value : values) {
                String[] parts = value.toString().split("\\t", 3);
                if (parts.length < 3) {
                    continue;
                }

                double alcohol = Double.parseDouble(parts[0]);
                String beer = parts[1] + "\tbrewery=" + parts[2];
                if (alcohol > maxAlcohol) {
                    maxAlcohol = alcohol;
                    beers.clear();
                    beers.add(beer);
                } else if (alcohol == maxAlcohol) {
                    beers.add(beer);
                }
            }

            String alcohol = normalizeAlcohol(Double.toString(maxAlcohol));
            for (String beer : beers) {
                context.write(new Text(alcohol), new Text(beer));
            }
        }
    }

    private static boolean runCountByAlcohol(String input, String output) throws Exception {
        Job job = Job.getInstance(new Configuration(), "q1 count beers by alcohol percentage");
        job.setJarByClass(BeerAnalysis.class);
        job.setMapperClass(CountByAlcoholMapper.class);
        job.setCombinerClass(SumReducer.class);
        job.setReducerClass(SumReducer.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);
        FileInputFormat.addInputPath(job, new Path(input));
        FileOutputFormat.setOutputPath(job, new Path(output));
        return job.waitForCompletion(true);
    }

    private static boolean runMostCommon(String input, String output) throws Exception {
        Job job = Job.getInstance(new Configuration(), "q2 most common alcohol percentage");
        job.setJarByClass(BeerAnalysis.class);
        job.setMapperClass(MostCommonMapper.class);
        job.setReducerClass(MostCommonReducer.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);
        job.setNumReduceTasks(1);
        FileInputFormat.addInputPath(job, new Path(input));
        FileOutputFormat.setOutputPath(job, new Path(output));
        return job.waitForCompletion(true);
    }

    private static boolean runBeersByAlcohol(String input, String output, String alcohol) throws Exception {
        Configuration conf = new Configuration();
        conf.set("beer.target.alcohol", alcohol);
        Job job = Job.getInstance(conf, "q3 beers by selected alcohol percentage");
        job.setJarByClass(BeerAnalysis.class);
        job.setMapperClass(BeersByAlcoholMapper.class);
        job.setReducerClass(PassThroughReducer.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        FileInputFormat.addInputPath(job, new Path(input));
        FileOutputFormat.setOutputPath(job, new Path(output));
        return job.waitForCompletion(true);
    }

    private static boolean runBeerAndBreweryCount(String input, String output) throws Exception {
        Job job = Job.getInstance(new Configuration(), "q4 beer and brewery count by alcohol percentage");
        job.setJarByClass(BeerAnalysis.class);
        job.setMapperClass(BeerAndBreweryCountMapper.class);
        job.setReducerClass(BeerAndBreweryCountReducer.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        FileInputFormat.addInputPath(job, new Path(input));
        FileOutputFormat.setOutputPath(job, new Path(output));
        return job.waitForCompletion(true);
    }

    private static boolean runHighestAlcohol(String input, String output) throws Exception {
        Job job = Job.getInstance(new Configuration(), "q5 beers with highest alcohol percentage");
        job.setJarByClass(BeerAnalysis.class);
        job.setMapperClass(HighestAlcoholMapper.class);
        job.setReducerClass(HighestAlcoholReducer.class);
        job.setMapOutputKeyClass(Text.class);
        job.setMapOutputValueClass(Text.class);
        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(Text.class);
        job.setNumReduceTasks(1);
        FileInputFormat.addInputPath(job, new Path(input));
        FileOutputFormat.setOutputPath(job, new Path(output));
        return job.waitForCompletion(true);
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 3) {
            System.err.println("Usage:");
            System.err.println("  BeerAnalysis countByAlcohol <input> <output>");
            System.err.println("  BeerAnalysis mostCommon <countByAlcoholOutput> <output>");
            System.err.println("  BeerAnalysis beersByAlcohol <input> <output> <alcoholPercentage>");
            System.err.println("  BeerAnalysis beerAndBreweryCount <input> <output>");
            System.err.println("  BeerAnalysis highestAlcohol <input> <output>");
            System.exit(2);
        }

        String command = args[0];
        boolean success;
        if ("countByAlcohol".equals(command)) {
            success = runCountByAlcohol(args[1], args[2]);
        } else if ("mostCommon".equals(command)) {
            success = runMostCommon(args[1], args[2]);
        } else if ("beersByAlcohol".equals(command)) {
            if (args.length < 4) {
                System.err.println("Missing alcoholPercentage argument.");
                System.exit(2);
            }
            success = runBeersByAlcohol(args[1], args[2], args[3]);
        } else if ("beerAndBreweryCount".equals(command)) {
            success = runBeerAndBreweryCount(args[1], args[2]);
        } else if ("highestAlcohol".equals(command)) {
            success = runHighestAlcohol(args[1], args[2]);
        } else {
            System.err.println("Unknown command: " + command);
            System.exit(2);
            return;
        }

        System.exit(success ? 0 : 1);
    }
}
